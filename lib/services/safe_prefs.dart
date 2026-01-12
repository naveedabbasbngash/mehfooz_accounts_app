import 'package:shared_preferences/shared_preferences.dart';

class SafePrefs {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> instance() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}