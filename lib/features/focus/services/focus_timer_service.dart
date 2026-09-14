import 'package:shared_preferences/shared_preferences.dart';

/// Minimal persistence for an active focus session, so a live notification
/// (and the in-app status pill) can reflect it even after the user
/// navigates away from [FocusTimerScreen]. Stores an absolute end-time
/// rather than start+duration, since that's what the chronometer
/// notification needs directly.
class FocusTimerService {
  static const _endMsKey = 'focus_timer_end_ms';

  static Future<void> start(Duration remaining) async {
    final endTime = DateTime.now().add(remaining);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_endMsKey, endTime.millisecondsSinceEpoch);
  }

  static Future<void> cancel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_endMsKey);
  }

  static Future<bool> isActive() async {
    final remaining = await getRemainingSeconds();
    return remaining > 0;
  }

  static Future<int> getRemainingSeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final endMs = prefs.getInt(_endMsKey);
    if (endMs == null) return 0;
    final remaining = (endMs - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining < 0 ? 0 : remaining;
  }
}
