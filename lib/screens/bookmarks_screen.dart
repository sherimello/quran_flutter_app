import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../services/database_service.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  // Map<FolderName, List<Bookmark>>
  Map<String, List<Map<String, dynamic>>> _folders = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookmarks();
  }

  Future<void> _fetchBookmarks() async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

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
          : _folders.isEmpty
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
                        content: Text('Remove all bookmarks in "$folderName"?'),
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
                    leading: const Icon(Icons.folder),
                    children: bookmarks.map((bookmark) {
                      return ListTile(
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Bookmark?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
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
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        title: Text(
                          'Surah ${bookmark['surah_number']} : Ayah ${bookmark['ayah_number']}',
                        ),
                        subtitle: Text(
                          'Saved on ${bookmark['updated_at'].toString().split('T')[0]}',
                        ),
                        onTap: () {
                          // Navigate to SurahDetailScreen and scroll to Ayah
                          // For MVP just standard nav or pop
                        },
                      );
                    }).toList(),
                  ),
                );
              },
            ),
    );
  }
}
