import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';
import 'surah_detail_screen.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  Map<String, List<Map<String, dynamic>>> _folders = {};
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _isLoggedIn = SupabaseService().currentUser != null;
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    try {
      final data = await DatabaseService().getAllBookmarks();
      final Map<String, List<Map<String, dynamic>>> folders = {};

      for (var item in data) {
        final folder = item['folder_name'] ?? 'General';
        if (!folders.containsKey(folder)) {
          folders[folder] = [];
        }
        folders[folder]!.add(item);
      }

      if (mounted) {
        setState(() {
          _folders = folders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading bookmarks: $e')));
      }
    }
  }

  Future<void> _deleteBookmark(int id, int? remoteId) async {
    try {
      await SupabaseService().deleteBookmark(id, remoteId);
      _fetchBookmarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _deleteFolder(String folderName) async {
    try {
      await SupabaseService().deleteFolder(folderName);
      _fetchBookmarks();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bookmarks')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Guest banner – shows a prompt to login for cloud backup
                if (!_isLoggedIn)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.08),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.cloud_upload,
                          size: 18,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Sign in to back up your bookmarks to the cloud.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _folders.isEmpty
                      ? const Center(child: Text('No bookmarks found'))
                      : ListView.builder(
                          itemCount: _folders.keys.length,
                          itemBuilder: (context, index) {
                            final folderName = _folders.keys.elementAt(index);
                            final bookmarks = _folders[folderName]!;

                            return GestureDetector(
                              onLongPress: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Folder?'),
                                    content: Text(
                                      'Remove all bookmarks in "$folderName"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                          _deleteFolder(folderName);
                                        },
                                        child: const Text(
                                          'Delete',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              child: ExpansionTile(
                                title: Text(folderName),
                                leading: const Icon(CupertinoIcons.folder),
                                children: bookmarks.map((bookmark) {
                                  // Show a sync indicator for pending bookmarks
                                  final isPending =
                                      (bookmark['pending_sync'] as int? ?? 0) ==
                                      1;
                                  return ListTile(
                                    onLongPress: () {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Delete Bookmark?'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('Cancel'),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context);
                                                _deleteBookmark(
                                                  bookmark['id'],
                                                  bookmark['remote_id'],
                                                );
                                              },
                                              child: const Text(
                                                'Delete',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    title: Text(
                                      'Surah ${bookmark['surah_number']} : Ayah ${bookmark['ayah_number']}',
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPending)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Icon(
                                              CupertinoIcons.cloud_upload,
                                              size: 14,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        Text(
                                          '${bookmark['surah_number']}',
                                          style: const TextStyle(
                                            fontFamily: 'surahname',
                                            fontSize: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      'Saved on ${bookmark['updated_at'].toString().split('T')[0]}',
                                    ),
                                    onTap: () async {
                                      final surah = await DatabaseService()
                                          .getSurahByNumber(
                                            bookmark['surah_number'],
                                          );
                                      if (surah != null && mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => SurahDetailScreen(
                                              surah: surah,
                                              initialAyah:
                                                  bookmark['ayah_number'],
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
