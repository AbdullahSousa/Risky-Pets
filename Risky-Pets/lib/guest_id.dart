import 'package:shared_preferences/shared_preferences.dart';

class GuestId {
  static const _key = 'guest_id';

  static Future<String> get() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString(_key);
    if (id == null) {
      id = 'guest_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_key, id);
    }
    return id;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}