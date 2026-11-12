import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/native_controls.dart';

/// Bridges Flutter to the Android native ringtone picker and RingtoneManager.
/// On iOS or web, all calls are no-ops and the bundled asset sounds are used.
class RingtoneService {
  static const _channel = NativeControls.channel;
  static const _prefKey = 'sound.alarm.selected';
  static const _prefTitleKey = 'sound.alarm.selected.title';

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Opens the OS ringtone picker. Returns the picked URI string, or null if
  /// the user cancelled. It doesn't save anything: picking a tone for one
  /// alarm used to overwrite the app-wide default in Settings.
  static Future<String?> pickRingtone({String? currentUri}) async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>(
        'pickRingtone',
        {'currentUri': currentUri},
      );
    } catch (_) {
      return null;
    }
  }

  /// Copies a picked phone ringtone (content://) into the app's own storage
  /// and returns the file path, so the alarm plugin can play it by itself
  /// even when the app process is dead. Null if it can't be copied.
  static Future<String?> cacheToFile(String uri) async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('cacheRingtone', {'uri': uri});
    } catch (e) {
      debugPrint('Could not cache ringtone $uri: $e');
      return null;
    }
  }

  /// Returns the human-readable display name of a ringtone URI.
  static Future<String> getTitleForUri(String uri) async {
    if (!_isAndroid) return 'Default Alarm';
    try {
      final title = await _channel.invokeMethod<String>(
        'getRingtoneTitle',
        {'uri': uri},
      );
      return title ?? 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  /// Returns the device default alarm tone URI string.
  static Future<String?> getDefaultAlarmUri() async {
    if (!_isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('getDefaultAlarmUri');
    } catch (_) {
      return null;
    }
  }

  /// True when the stored sound is a native content:// URI.
  static bool isNativeUri(String sound) => sound.startsWith('content://');

  /// Loads the saved alarm sound value from prefs.
  static Future<String> getSavedSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey) ?? 'default';
  }

  /// Loads the saved display title from prefs.
  static Future<String> getSavedTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefTitleKey) ?? 'Default Alarm';
  }

  /// Saves a sound selection (asset path or native URI) with its display title.
  static Future<void> saveSound(String sound, String title) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, sound);
    await prefs.setString(_prefTitleKey, title);
  }
}
