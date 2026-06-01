import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'base.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';


final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode');
  if (isDarkMode != null) {
    themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // FIX: store subscription so we can cancel it in dispose()
  late final _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
    (User? user) {
      // Auth state monitored at app level — no UI rebuild needed here
      debugPrint(user == null ? 'Auth: signed out' : 'Auth: signed in');
    },
  );

  @override
  void dispose() {
    // FIX: cancel the stream to prevent leaks
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Risky Pets',
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          themeMode: currentMode,
          // FIX: use a real title that exists in _titles list, or just 'Home'
          home: const MyHomePage(title: 'Home'),
        );
      },
    );
  }
}
