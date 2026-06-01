import 'package:flutter/material.dart';
import 'package:risky_pets/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Settings Screen
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}


class _SettingsScreenState extends State<SettingsScreen> {
  bool _isNotificationsOn = true;
  bool _isCameraOn = true;
  bool _isMicOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 10),
          children: [
            SwitchListTile(
              secondary: const Icon(Icons.notifications_none),
              title: const Text("Notifications"),
              value: _isNotificationsOn,
              onChanged: (on) => setState(() => _isNotificationsOn = on),
            ),

            ValueListenableBuilder<ThemeMode>(
                valueListenable: themeNotifier,
                builder: (context, currentMode, child) {
                  return SwitchListTile(
                    title: const Text('Dark Mode'),
                    subtitle: const Text('Use dark theme'),
                    value: currentMode == ThemeMode.dark, 
                    onChanged: (value) async{
                      themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isDarkMode', value);
                    },
                    secondary: const Icon(Icons.dark_mode),
                  );
                },
              ),

            const Divider(),

            ExpansionTile(  
            leading: const Icon(Icons.settings_display),
              title: const Text("App Permissions"),
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.camera_alt, size: 20),
                  title: const Text("Camera Access"),
                  value: _isCameraOn,
                  onChanged: (on) => setState(() => _isCameraOn = on),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.mic, size: 20),
                  title: const Text("Microphone Access"),
                  value: _isMicOn,
                  onChanged: (on) => setState(() => _isMicOn = on),
                ),
              ],
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.language),
              title: const Text("Language"),
              trailing: const Text("English"),
              onTap: () {},
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("About app"),
              onTap: () {},
            ),
            
            const SizedBox(height: 30),
            const Center(child: Text("v1.0.0", style: TextStyle(color: Colors.grey))),
          ],
        ),
      ),
    );
  }
}