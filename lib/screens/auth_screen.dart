import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/supabase_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController =
      TextEditingController(); // Added for registration

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // FIX: Add listener to rebuild UI when tab changes
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Don't forget to dispose
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      if (email.isEmpty || password.isEmpty) {
        throw Exception('Please enter email and password');
      }

      if (_tabController.index == 0) {
        // --- LOGIN FLOW ---
        await SupabaseService().signIn(email, password);
      } else {
        // --- REGISTER FLOW ---
        final confirmPassword = _confirmPasswordController.text.trim();

        // Validation: Check if passwords match
        if (password != confirmPassword) {
          throw Exception('Passwords do not match');
        }

        await SupabaseService().signUp(email, password);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registration successful! Please login.'),
              backgroundColor: Colors.green,
            ),
          );
          // Clear inputs and switch to login
          _confirmPasswordController.clear();
          _passwordController.clear();
          _tabController.animateTo(0);

          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // Navigate to Home on success (for Login) and sync offline bookmarks
      if (mounted) {
        // Fire-and-forget: sync any local/guest bookmarks to cloud
        SupabaseService().syncBookmarks().catchError((_) {});
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      log(e.toString().replaceAll('Exception: ', ''));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we are in Register mode
    final isRegistering = _tabController.index == 1;
    var size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppBar().preferredSize.height * 1.5,
        title: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (builder) => const HomeScreen()),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
              ), // Removed hardcoded white color for better theme adaptation
            ),
            const SizedBox(width: 17),
            Text(
              'Account',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: size.width * .041,
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        // Added scroll view to prevent overflow on small screens
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ClipRRect(
                borderRadius:  BorderRadius.circular(1000),
                child: TabBar(
                  indicatorSize: TabBarIndicatorSize.tab,
                  controller: _tabController,
                  padding: EdgeInsets.all(21),
                  dividerHeight: 0,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  splashBorderRadius:  BorderRadius.circular(1000),
                  labelStyle: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: size.width * .037,
                    color: const Color(0xff34da15),
                  ),
                  tabs: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1000),
                      child: const Tab(text: 'Login'),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(1000),
                      child: Tab(text: 'Register'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: const Color(0xff34da15).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      // labelText: 'Email',
                      hintText: 'Email',
                      hintStyle: GoogleFonts.poppins(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 0,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.mail_solid,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 21),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: const Color(0xff34da15).withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Center(
                  child: TextField(
                    controller: _passwordController,
                    decoration: InputDecoration(
                      // labelText: 'Email',
                      hintText: 'Password',
                      hintStyle: GoogleFonts.poppins(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 0,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(
                        CupertinoIcons.lock_fill,
                        size: 20,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 21),
                    ),
                    obscureText: true,
                  ),
                ),
              ),

              // Animated Switcher or Conditional UI for Confirm Password
              if (isRegistering) ...[
                const SizedBox(height: 16),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xff34da15).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: TextField(
                    controller:
                        _confirmPasswordController, // Use separate controller
                    decoration: InputDecoration(
                      hintText: 'Confirm Password',
                      hintStyle: GoogleFonts.poppins(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: .55),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 0,
                      ),
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.lock_outline),
                      contentPadding: const EdgeInsets.symmetric(vertical: 21),
                    ),
                    obscureText: true,
                  ),
                ),
              ],

              const SizedBox(height: 32),
              SizedBox(
                // width: double.infinity,
                height: AppBar().preferredSize.height * .87,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(
                      const Color(0xff34da15),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        )
                      : Text(
                          isRegistering ? 'Register' : 'Login',
                          style: GoogleFonts.poppins(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
