import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// A live, ticking countdown notification for an active nap or focus timer —
/// the closest Android equivalent to an iOS Dynamic Island/Live Activity.
///
/// Needs no native code at all: `AndroidNotificationDetails.usesChronometer`
/// (combined with `chronometerCountDown` and an absolute `when`) tells
/// Android's own notification renderer to count down natively. Nothing here
/// ticks a per-second timer — the OS does that, so the countdown keeps
/// running correctly through Doze/background with zero app wake-ups.
///
/// Android-only: iOS has no notification chronometer, and a real Dynamic
/// Island/Live Activity needs a native ActivityKit extension (see
/// ios/WIDGET_SETUP.md for why that's out of scope here). The in-app
/// `LiveStatusIsland` covers iOS instead, while the app is foregrounded.
class LiveTimerNotificationService {
  LiveTimerNotificationService._();

  static const _channelId = 'alarm_plus_live_timer';
  static const _channelName = 'Live Timers';
  static const _notificationId = 778899;

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> showNap(int remainingSeconds) =>
      _show(title: 'Nap in progress', remainingSeconds: remainingSeconds);

  static Future<void> showFocus(int remainingSeconds) => _show(
        title: 'Focus session in progress',
        remainingSeconds: remainingSeconds,
      );

  static Future<void> _show({
    required String title,
    required int remainingSeconds,
  }) async {
    if (!_supported || remainingSeconds <= 0) return;

    final endTime = DateTime.now().add(Duration(seconds: remainingSeconds));

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription:
          'A live countdown while a nap or focus timer is running.',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      usesChronometer: true,
      chronometerCountDown: true,
      when: endTime.millisecondsSinceEpoch,
      category: AndroidNotificationCategory.stopwatch,
      icon: '@mipmap/ic_launcher',
    );

    try {
      await _notifications.show(
        _notificationId,
        title,
        'Tap to return to Alarm+',
        NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('LiveTimerNotificationService.show failed: $e');
    }
  }

  static Future<void> cancel() async {
    if (!_supported) return;
    try {
      await _notifications.cancel(_notificationId);
    } catch (e) {
      debugPrint('LiveTimerNotificationService.cancel failed: $e');
    }
  }
}
