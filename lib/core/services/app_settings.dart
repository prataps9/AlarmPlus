import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that the UI reads synchronously. [load] runs before
/// `runApp`, so the first frame already has the saved theme (no white flash
/// for a dark-mode user).
class AppSettings {
  AppSettings._();

  static const themeModeKey = 'appearance.theme_mode';
  static const vibrationKey = 'alarm.vibration_enabled';

  static ThemeMode _themeMode = ThemeMode.light;
  static bool _vibration = true;

  static ThemeMode get themeMode => _themeMode;
  static bool get vibrationEnabled => _vibration;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = parseThemeMode(prefs.getString(themeModeKey));
    _vibration = prefs.getBool(vibrationKey) ?? true;
  }

  /// Light stays the default: the app was designed white-first, and a user
  /// who never touches the setting keeps what they had.
  static ThemeMode parseThemeMode(String? raw) => ThemeMode.values
      .firstWhere((m) => m.name == raw, orElse: () => ThemeMode.light);

  static Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themeModeKey, mode.name);
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

  static String themeModeLabel(ThemeMode mode) => switch (mode) {
        ThemeMode.system => 'Match phone',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}

/// Live theme mode; write through [AppSettings.setThemeMode] as well.
final themeModeProvider =
    StateProvider<ThemeMode>((ref) => AppSettings.themeMode);
