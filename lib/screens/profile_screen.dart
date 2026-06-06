import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase_service.dart';
import 'auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  int _totalBookmarks = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await SupabaseService().getUserStats();
    if (mounted) {
      setState(() {
        _totalBookmarks = stats['totalBookmarks'] ?? 0;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService().currentUser;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap: () async {
              await SupabaseService().signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                  (route) => false,
                );
              }
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              margin: EdgeInsets.only(right: 13),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(1000),
              ),
              child: Text(
                'Logout',
                style: GoogleFonts.poppins(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  height: 0,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: size.width * .041,
          ),
        ),
        toolbarHeight: AppBar().preferredSize.height * 1.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: AppBar().preferredSize.height * 2,
                    height: AppBar().preferredSize.height * 2,
                    decoration: BoxDecoration(
                      color: const Color(0xff34da15),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(size.width * .65),
                        bottomLeft: Radius.circular(size.width * .5),
                        topRight: Radius.circular(size.width * .75),
                        bottomRight: Radius.circular(size.width * .75),
                      ),
                    ),
                    child: Icon(CupertinoIcons.person, size: size.width * .1),
                  ),
                  const SizedBox(height: 17),
                  Text(
                    user?.email ?? 'Unknown User',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * .041,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 48),
                  _buildStatTile('Total Bookmarks', '$_totalBookmarks'),
                  // const Spacer(),
                  // SizedBox(
                  //   width: double.infinity,
                  //   child: ElevatedButton.icon(
                  //     style: ElevatedButton.styleFrom(
                  //       backgroundColor: Colors.red,
                  //       foregroundColor: Colors.white,
                  //       padding: const EdgeInsets.all(16),
                  //     ),
                  //     onPressed: () async {
                  //       await SupabaseService().signOut();
                  //       if (mounted) {
                  //         Navigator.pushAndRemoveUntil(
                  //           context,
                  //           MaterialPageRoute(
                  //             builder: (_) => const AuthScreen(),
                  //           ),
                  //           (route) => false,
                  //         );
                  //       }
                  //     },
                  //     icon: const Icon(Icons.logout),
                  //     label: const Text('Logout'),
                  //   ),
                  // ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatTile(String label, String value) {
    var size = MediaQuery.of(context).size;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 21, horizontal: 31),
      decoration: BoxDecoration(
        color: const Color(0xff34da15).withOpacity(0.13),
        borderRadius: BorderRadius.circular(1000),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: size.width * .037)),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 21,
              height: 0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
