import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'history.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _userNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  User? _currentUser;


  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (!mounted) return;
      setState(() {
        _currentUser = user;
      });
    });
  }

  @override
  void dispose() {
    // FIX: cancel stream + dispose controllers
    _authSubscription?.cancel();
    _userNameController.dispose();
    _emailController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.red : Colors.green,
    ));
  }

  // FIX: actually calls Firebase to update display name
  Future<void> _updateUsername() async {
    final name = _userNameController.text.trim();
    if (name.isEmpty) {
      _showSnack('Username cannot be empty.', error: true);
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
      await FirebaseAuth.instance.currentUser?.reload();
      setState(() {
        _currentUser = FirebaseAuth.instance.currentUser;
      });
      _userNameController.clear();
      _showSnack('Username updated successfully.');
    } catch (e) {
      _showSnack('Failed to update username: $e', error: true);
    }
  }

  // FIX: actually calls Firebase to update email (requires re-auth for newer SDK versions)
  Future<void> _updateEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack('Email cannot be empty.', error: true);
      return;
    }
    try {
      await FirebaseAuth.instance.currentUser?.verifyBeforeUpdateEmail(email);
      _emailController.clear();
      _showSnack('Verification sent to $email. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Failed to update email.';
      if (e.code == 'requires-recent-login') {
        msg = 'Please sign out and sign back in before changing your email.';
      }
      _showSnack(msg, error: true);
    }
  }

  // FIX: actually re-authenticates then updates password
  Future<void> _updatePassword() async {
    final oldPw = _oldPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    if (oldPw.isEmpty || newPw.isEmpty || confirmPw.isEmpty) {
      _showSnack('Please fill in all password fields.', error: true);
      return;
    }
    if (newPw != confirmPw) {
      _showSnack('New passwords do not match.', error: true);
      return;
    }
    if (newPw.length < 6) {
      _showSnack('Password must be at least 6 characters.', error: true);
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        _showSnack('No signed-in user found.', error: true);
        return;
      }
      // Re-authenticate before changing password
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: oldPw,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPw);

      _oldPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnack('Password updated successfully.');
    } on FirebaseAuthException catch (e) {
      String msg = e.message ?? 'Failed to update password.';
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Current password is incorrect.';
      }
      _showSnack(msg, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: Colors.green.shade100,
                    backgroundImage: _currentUser?.photoURL != null
                        ? NetworkImage(_currentUser!.photoURL!)
                        : null,
                    child: _currentUser?.photoURL == null
                        ? const Icon(Icons.person,
                            size: 60, color: Colors.green)
                        : null,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    _currentUser?.displayName ?? 'No name',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _currentUser?.email ?? 'No email',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),
            const Divider(indent: 20, endIndent: 20),

            ExpansionTile(
              shape: const Border(),
              collapsedShape: const Border(),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Profile'),
              children: [

                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Change Username'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _userNameController,
                            decoration: const InputDecoration(
                              labelText: 'New Username',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // FIX: calls Firebase instead of setting local variable
                          ElevatedButton(
                            onPressed: _updateUsername,
                            child: const Text('Update Username'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Change Email'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'New Email',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          // FIX: calls Firebase instead of setting local variable
                          ElevatedButton(
                            onPressed: _updateEmail,
                            child: const Text('Update Email'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change Password'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _oldPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Current Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _newPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Confirm New Password',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // FIX: calls Firebase re-auth + updatePassword
                          ElevatedButton(
                            onPressed: _updatePassword,
                            child: const Text('Update Password'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // FIX: My Activity now navigates to HistoryScreen
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('My Activity'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const HistoryScreen()),
                );
              },
            ),
            // FIX: Notifications tile placeholder — shows a coming-soon snackbar
            ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: const Text('Notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Notification settings coming soon.')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
