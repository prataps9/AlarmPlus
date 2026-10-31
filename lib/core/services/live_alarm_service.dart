import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/upcoming_rings.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

/// The next ring the live countdown is about.
typedef LiveRing = ({AlarmModel alarm, DateTime at, bool snoozed});

/// Keeps the native live countdown (LiveActivity.kt) on the soonest ring:
/// a lock-screen countdown that Android 16+ promotes to a status-bar capsule,
/// like a Swiggy/Zomato order tracker. Native shows it [AlarmService.upcomingNoticeLead]
/// before the ring and removes it at the ring, with the app open or closed.
class LiveAlarmService {
  LiveAlarmService._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// A background isolate (see BackgroundTasks) has no MainActivity, so its
  /// channel is the background runner's instead.
  static const _backgroundChannel = MethodChannel('alarmplus/background');

  static Future<T?> _invoke<T>(String method, Map<String, Object?> args) async {
    try {
      return await NativeControls.channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return _backgroundChannel.invokeMethod<T>(method, args);
    }
  }

  /// The soonest ring across [alarms] at [now]. [pending] holds snoozes and
  /// wake-check re-rings by alarm id: those replace the alarm's normal next
  /// time. Pure, so it can be tested.
  static LiveRing? pickNext(
    Iterable<AlarmModel> alarms,
    DateTime now,
    Map<int, DateTime> pending,
  ) {
    LiveRing? best;
    for (final alarm in alarms) {
      if (!alarm.isEnabled || alarm.isSystem) continue;
      final snooze = pending[AlarmService.alarmIntId(alarm.id)];
      DateTime? at = snooze;
      if (at == null) {
        final rings = upcomingRings([alarm], now, window: const Duration(days: 8));
        if (rings.isEmpty) continue;
        at = rings.first.at;
      }
      if (best == null || at.isBefore(best.at)) {
        best = (alarm: alarm, at: at, snoozed: snooze != null);
      }
    }
    return best;
  }

  /// The notification's wording for [ring].
  static ({String title, String text}) wording(
    LiveRing ring,
    DateTime now, {
    required bool use24h,
  }) {
    final time = TimeFormat.clockLabel(ring.at.hour, ring.at.minute, use24h: use24h);
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(ring.at.year, ring.at.month, ring.at.day);
    final days = day.difference(today).inDays;
    final when = days <= 0
        ? 'Today'
        : days == 1
            ? 'Tomorrow'
            : DateFormat('EEEE').format(ring.at);
    final label = ring.alarm.label.trim();
    return (
      title: ring.snoozed ? 'Snoozed · $time' : 'Alarm · $time',
      text: ring.snoozed
          ? (label.isEmpty ? 'Rings again soon' : label)
          : [when, if (label.isNotEmpty) label].join(' · '),
    );
  }

  /// Points the native countdown at the soonest ring (or clears it).
  static Future<void> sync() async {
    if (!_isAndroid) return;
    try {
      if (!await AlarmService.upcomingNoticeEnabled()) {
        await _invoke<void>('liveAlarmSync', {'ring': null});
        return;
      }
      final alarms = AlarmService.getAllAlarms().toList();
      final now = DateTime.now();
      final ring = pickNext(alarms, now, await AlarmService.pendingRings(alarms));
      if (ring == null) {
        await _invoke<void>('liveAlarmSync', {'ring': null});
        return;
      }
      final words = wording(
        ring,
        now,
        use24h: WidgetsBinding.instance.platformDispatcher.alwaysUse24HourFormat,
      );
      await _invoke<void>('liveAlarmSync', {
        'ring': jsonEncode({
          'alarmId': AlarmService.alarmIntId(ring.alarm.id),
          'dueMs': ring.at.millisecondsSinceEpoch,
          'windowMs': AlarmService.upcomingNoticeLead.inMilliseconds,
          'title': words.title,
          'text': words.text,
          'canSkip': !ring.snoozed,
        }),
      });
    } catch (e) {
      debugPrint('Live alarm sync failed: $e');
    }
  }
}
