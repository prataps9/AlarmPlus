import 'package:shared_preferences/shared_preferences.dart';

/// App-wide preferences that the UI reads synchronously. [load] runs before
/// `runApp`, so the first frame already has the saved values.
class AppSettings {
  AppSettings._();

  static const vibrationKey = 'alarm.vibration_enabled';

  static bool _vibration = true;

  static bool get vibrationEnabled => _vibration;

  /// Minutes an unanswered alarm rings before it is silenced and recorded
  /// as missed; 0 = never (like the stock Clock's "Silence after").
  static const silenceAfterKey = 'alarm.silence_after_minutes';
  static const silenceAfterChoices = [15, 20, 30, 45, 60, 0];
  static const defaultSilenceAfter = 30;
  static int _silenceAfter = defaultSilenceAfter;
  static int get silenceAfterMinutes => _silenceAfter;

  /// The ring's auto-silence delay, or null for "Never".
  static Duration? get silenceAfter =>
      _silenceAfter <= 0 ? null : Duration(minutes: _silenceAfter);

  /// What the volume keys do while an alarm rings. Read natively too
  /// (AlarmForegroundService), as "flutter.alarm.volume_buttons".
  static const volumeButtonsKey = 'alarm.volume_buttons';
  static VolumeButtons _volumeButtons = VolumeButtons.snooze;
  static VolumeButtons get volumeButtons => _volumeButtons;

  /// Turning the phone face down snoozes a ringing alarm.
  static const flipToSnoozeKey = 'alarm.flip_to_snooze';
  static bool _flipToSnooze = false;
  static bool get flipToSnooze => _flipToSnooze;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _vibration = prefs.getBool(vibrationKey) ?? true;
    final silence = prefs.getInt(silenceAfterKey) ?? defaultSilenceAfter;
    _silenceAfter =
        silenceAfterChoices.contains(silence) ? silence : defaultSilenceAfter;
    _volumeButtons = VolumeButtons.parse(prefs.getString(volumeButtonsKey));
    _flipToSnooze = prefs.getBool(flipToSnoozeKey) ?? false;
  }

  static Future<void> setSilenceAfterMinutes(int minutes) async {
    _silenceAfter = minutes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(silenceAfterKey, minutes);
  }

  static Future<void> setVolumeButtons(VolumeButtons v) async {
    _volumeButtons = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(volumeButtonsKey, v.name);
  }

  static Future<void> setFlipToSnooze(bool on) async {
    _flipToSnooze = on;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(flipToSnoozeKey, on);
  }

  /// "Silence after" as shown in Settings.
  static String silenceAfterLabel(int minutes) =>
      minutes <= 0 ? 'Never' : '$minutes minutes';

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

/// What the volume keys do while an alarm rings, like the stock Clock's
/// setting. There is deliberately no "Dismiss": it would skip the wake
/// challenge.
enum VolumeButtons {
  snooze('Snooze'),
  volume('Change volume'),
  nothing('Do nothing');

  const VolumeButtons(this.label);
  final String label;

  static VolumeButtons parse(String? name) =>
      values.where((v) => v.name == name).firstOrNull ?? snooze;
}
