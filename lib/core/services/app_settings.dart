import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that the UI reads synchronously. [load] runs before
/// `runApp`, so the first frame already has the saved values.
class AppSettings {
  AppSettings._();

  static const vibrationKey = 'alarm.vibration_enabled';

  static bool _vibration = true;

  static bool get vibrationEnabled => _vibration;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _vibration = prefs.getBool(vibrationKey) ?? true;
  }

  static Future<void> setVibrationEnabled(bool on) async {
    _vibration = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(vibrationKey, on);
  }

  /// Reads the saved value fresh, for code that may run in a background
  /// isolate where [load] never ran.
  static Future<bool> readVibrationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(vibrationKey) ?? true;
  }
}
