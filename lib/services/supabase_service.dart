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

  // Sync bookmarks
  Future<void> saveBookmark(String folderName, int surahId, int ayahId) async {
    if (currentUser == null) return;

    final bookmarkData = {
      'user_id': currentUser!.id,
      'folder_name': folderName,
      'surah_id': surahId,
      'ayah_id': ayahId,
      'updated_at': DateTime.now().toIso8601String(),
    };

    try {
      // Save to Supabase
      final response = await _client
          .from('bookmarks')
          .upsert(bookmarkData)
          .select();

      // Save to Local DB (including remote_id if possible)
      int? remoteId;
      if ((response as List).isNotEmpty) {
        remoteId = response[0]['id'];
      }

      await DatabaseService().insertBookmark({
        'remote_id': remoteId,
        'folder_name': folderName,
        'surah_number': surahId,
        'ayah_number': ayahId,
        'user_id': currentUser!.id,
        'updated_at': bookmarkData['updated_at'],
      });
    } catch (e) {
      // Offline fallback: save only locally with null remote_id
      await DatabaseService().insertBookmark({
        'remote_id': null,
        'folder_name': folderName,
        'surah_number': surahId,
        'ayah_number': ayahId,
        'user_id': currentUser!.id,
        'updated_at': bookmarkData['updated_at'],
      });
    }
  }

  Future<void> syncBookmarks() async {
    if (currentUser == null) return;
    try {
      final response = await _client
          .from('bookmarks')
          .select()
          .eq('user_id', currentUser!.id);

      final List<dynamic> remoteBookmarks = response;
      final dbService = DatabaseService();

      await dbService.clearLocalBookmarks();

      for (var rb in remoteBookmarks) {
        await dbService.insertBookmark({
          'remote_id': rb['id'],
          'folder_name': rb['folder_name'],
          'surah_number': rb['surah_id'],
          'ayah_number': rb['ayah_id'],
          'user_id': rb['user_id'],
          'updated_at': rb['updated_at'],
        });
      }
    } catch (e) {
      print('Sync failed: $e');
    }
  }

  Future<List<String>> getFolders() async {
    if (currentUser == null) return [];
    // Fetch from local instead of remote
    final localBookmarks = await DatabaseService().getAllBookmarks();
    return localBookmarks
        .map((e) => e['folder_name'] as String)
        .toSet()
        .toList();
  }

  Future<void> deleteBookmark(int localId, int? remoteId) async {
    // Delete locally
    await DatabaseService().deleteBookmarkLocally(localId);

    // Delete remotely if remoteId exists
    if (remoteId != null) {
      try {
        await _client.from('bookmarks').delete().eq('id', remoteId);
      } catch (e) {
        print('Remote delete failed: $e');
      }
    }
  }

  Future<void> deleteFolder(String folderName) async {
    if (currentUser == null) return;

    // Delete locally
    await DatabaseService().deleteFolderLocally(folderName);

    // Delete remotely
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

  Future<Map<String, dynamic>> getUserStats() async {
    if (currentUser == null) return {};
    // Fetch from local
    final localBookmarks = await DatabaseService().getAllBookmarks();
    return {'totalBookmarks': localBookmarks.length};
  }
}
