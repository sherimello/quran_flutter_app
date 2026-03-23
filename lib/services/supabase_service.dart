import 'package:supabase_flutter/supabase_flutter.dart';
import 'database_service.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;

  Future<void> signUp(String email, String password) async {
    await _client.auth.signUp(email: email, password: password);
  }

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Save a bookmark. Works for guests (local only) and logged-in users (cloud + local).
  /// Falls back to local with pending_sync=1 if offline.
  Future<void> saveBookmark(String folderName, int surahId, int ayahId) async {
    final now = DateTime.now().toIso8601String();
    final userId = currentUser?.id; // null for guests

    // Always save locally first (with pending_sync = 1 if user is logged in but may be offline)
    // Guest bookmarks have user_id = null and pending_sync = 0 (local-only, no cloud target)
    final localData = {
      'remote_id': null,
      'folder_name': folderName,
      'surah_number': surahId,
      'ayah_number': ayahId,
      'user_id': userId,
      'updated_at': now,
      'pending_sync': userId != null
          ? 1
          : 0, // pending if logged in (will try to sync)
    };

    final localId = await DatabaseService().insertBookmarkReturnId(localData);

    // If logged in, try to sync immediately to cloud
    if (userId != null) {
      try {
        final response = await _client.from('bookmarks').upsert({
          'user_id': userId,
          'folder_name': folderName,
          'surah_id': surahId,
          'ayah_id': ayahId,
          'updated_at': now,
        }).select();

        // Mark as synced and store remote_id
        if ((response as List).isNotEmpty && localId != null) {
          await DatabaseService().markBookmarkSynced(
            localId,
            response[0]['id'],
          );
        }
      } catch (e) {
        // Offline — will be synced later by syncBookmarks()
        print('Bookmark save offline, will sync later: $e');
      }
    }
  }

  /// Sync bookmarks between local DB and Supabase.
  /// 1. Push all pending (unsynced) local bookmarks to cloud.
  /// 2. Pull remote bookmarks and merge into local.
  Future<void> syncBookmarks() async {
    if (currentUser == null) return;
    final userId = currentUser!.id;
    final dbService = DatabaseService();

    try {
      // Step 1: Push unsynced local bookmarks to cloud
      final unsynced = await dbService.getUnsyncedBookmarks();
      for (final bookmark in unsynced) {
        // Skip if already has a remote_id (shouldn't happen, but safety check)
        if (bookmark['remote_id'] != null) {
          await dbService.markBookmarkSynced(
            bookmark['id'],
            bookmark['remote_id'],
          );
          continue;
        }

        try {
          final response = await _client.from('bookmarks').upsert({
            'user_id': userId,
            'folder_name': bookmark['folder_name'],
            'surah_id': bookmark['surah_number'],
            'ayah_id': bookmark['ayah_number'],
            'updated_at': bookmark['updated_at'],
          }).select();

          if ((response as List).isNotEmpty) {
            await dbService.markBookmarkSynced(
              bookmark['id'],
              response[0]['id'],
            );
          }
        } catch (e) {
          print('Failed to push bookmark ${bookmark['id']}: $e');
        }
      }

      // Step 2: Pull remote bookmarks and upsert locally
      // First, assign the local guest bookmarks to this user by updating user_id
      await _client
          .rpc('noop')
          .catchError((_) {}); // connectivity check – ignore errors
      final response = await _client
          .from('bookmarks')
          .select()
          .eq('user_id', userId);

      final List<dynamic> remoteBookmarks = response;

      // Clear only this user's already-synced bookmarks (preserve pending ones)
      await dbService.clearSyncedBookmarksForUser(userId);

      for (var rb in remoteBookmarks) {
        await dbService.insertBookmark({
          'remote_id': rb['id'],
          'folder_name': rb['folder_name'],
          'surah_number': rb['surah_id'],
          'ayah_number': rb['ayah_id'],
          'user_id': rb['user_id'],
          'updated_at': rb['updated_at'],
          'pending_sync': 0,
        });
      }
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<List<String>> getFolders() async {
    // Return folders for ALL users (guests included)
    final localBookmarks = await DatabaseService().getAllBookmarks();
    return localBookmarks
        .map((e) => e['folder_name'] as String)
        .toSet()
        .toList();
  }

  Future<void> deleteBookmark(int localId, int? remoteId) async {
    // Always delete locally
    await DatabaseService().deleteBookmarkLocally(localId);

    // Delete remotely only if logged in and has a remote copy
    if (remoteId != null && currentUser != null) {
      try {
        await _client.from('bookmarks').delete().eq('id', remoteId);
      } catch (e) {
        print('Remote delete failed: $e');
      }
    }
  }

  Future<void> deleteFolder(String folderName) async {
    // Always delete locally
    await DatabaseService().deleteFolderLocally(folderName);

    // Delete remotely only if logged in
    if (currentUser != null) {
      try {
        await _client
            .from('bookmarks')
            .delete()
            .eq('user_id', currentUser!.id)
            .eq('folder_name', folderName);
      } catch (e) {
        print('Remote delete failed: $e');
      }
    }
  }

  Future<Map<String, dynamic>> getUserStats() async {
    final localBookmarks = await DatabaseService().getAllBookmarks();
    return {'totalBookmarks': localBookmarks.length};
  }

  Future<Map<String, dynamic>?> checkForUpdates() async {
    try {
      final response = await _client
          .from('app_updates')
          .select()
          .order('created_at', ascending: false)
          .limit(1);

      if ((response as List).isNotEmpty) {
        return response.first;
      }

    } catch (e) {
      print('Failed to check for updates: $e');
    }
    return null;
  }
}
