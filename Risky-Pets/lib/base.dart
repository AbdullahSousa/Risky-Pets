import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home.dart';
import 'profile.dart';
import 'settings.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'history.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;
  User? _currentUser;

  // FIX: store subscription so it can be cancelled in dispose()
  StreamSubscription<User?>? _authSubscription;

  final List<Widget> _pages = [
    const HomeScreen(),
    const ProfileScreen(),
    const SettingsScreen(),
  ];

  final List<String> _titles = [
    'Home',
    'Profile',
    'Settings',
  ];

  @override
  void initState() {
    super.initState();

    _selectedIndex = _titles.indexOf(widget.title);
    if (_selectedIndex == -1) {
      _selectedIndex = 0;
    }

    // FIX: store and cancel auth subscription on dispose
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (User? user) {
        if (!mounted) return;
        setState(() {
          _currentUser = user;
        });
      },
    );
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _showProfileMenu(BuildContext context) async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    // FIX: capture a local non-null copy to avoid race condition with auth state changes
    final user = _currentUser;

    if (user != null) {
      showMenu<String>(
        context: context,
        position: position,
        items: <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            enabled: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: user.photoURL != null
                          ? NetworkImage(user.photoURL!)
                          : null,
                      child: user.photoURL == null
                          ? Text(
                              user.email?.substring(0, 1).toUpperCase() ?? 'U',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName ?? 'User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            user.email ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'History',
            child: Row(
              children: [
                Icon(Icons.history, size: 20, color: Colors.green[300]),
                const SizedBox(width: 8),
                Text('History', style: TextStyle(color: Colors.green[300])),
              ],
            ),
          ),
          // FIX: use local `user` — no more unsafe ! on _currentUser
          PopupMenuItem<String>(
            enabled: !user.emailVerified,
            onTap: user.emailVerified
                ? null
                : () async {
                    await FirebaseAuth.instance.currentUser
                        ?.sendEmailVerification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email has been sent.'),
                        ),
                      );
                    }
                  },
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: user.emailVerified ? Colors.green[300] : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(user.emailVerified
                    ? 'Email Verified'
                    : 'Send Verification Email'),
              ],
            ),
          ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: 'signout',
            child: Row(
              children: [
                Icon(Icons.logout, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Sign Out', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (!context.mounted) return;
        if (value == 'History') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryScreen()),
          );
        } else if (value == 'signout') {
          FirebaseAuth.instance.signOut().then((_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Signed out successfully')),
              );
            }
          });
        }
      });
    } else {
      showMenu<String>(
        context: context,
        position: position,
        items: const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(
            value: 'signin',
            child: Row(
              children: [
                Icon(Icons.login, size: 20),
                SizedBox(width: 8),
                Text('Sign In'),
              ],
            ),
          ),
          PopupMenuItem<String>(
            value: 'signup',
            child: Row(
              children: [
                Icon(Icons.person_add, size: 20),
                SizedBox(width: 8),
                Text('Sign Up'),
              ],
            ),
          ),
        ],
      ).then((value) {
        if (!context.mounted) return;
        if (value == 'signin') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignInScreen()),
          );
        } else if (value == 'signup') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignUpScreen()),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[300],
        title: Text(_titles[_selectedIndex]),
        actions: [
          Builder(
            builder: (context) => GestureDetector(
              onTap: () => _showProfileMenu(context),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.white,
                  backgroundImage: _currentUser?.photoURL != null
                      ? NetworkImage(_currentUser!.photoURL!)
                      : null,
                  child: _currentUser?.photoURL == null
                      ? Icon(
                          _currentUser != null
                              ? Icons.person
                              : Icons.account_circle,
                          size: 24,
                          color: _currentUser != null
                              ? Colors.green[300]
                              : Colors.grey[600],
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.green[300]),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.menu_book, size: 48, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Risky Pets',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() => _selectedIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() => _selectedIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() => _selectedIndex = 2);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: _pages[_selectedIndex],
    );
  }
}
