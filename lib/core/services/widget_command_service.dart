import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';

/// Applies commands raised outside the app — home-screen widget buttons and
/// the Quick Settings tile.
///
/// Alarm state lives in Hive, which the native side can't touch, so those
/// surfaces hand a command here instead. Two delivery routes, matching
/// `WidgetCommandBridge.kt`: a live method call when the app is running, and a
/// prefs-backed queue drained at startup when it isn't.
class WidgetCommandService {
  WidgetCommandService._();

  static const _channel = MethodChannel('alarmplus/alarm_controls');
  static const _pendingKey = 'widget_pending_commands';

  static const toggleNext = 'toggleNext';
  static const snooze = 'snooze';

  /// Reschedule anything stale — boot, timezone/clock change, app update, or
  /// the system next-alarm marker firing.
  static const resync = 'resync';

  static const showAlarms = 'showAlarms';
  static const dismissAlarm = 'dismissAlarm';
  static const setAlarm = 'setAlarm';
  static const newAlarm = 'newAlarm';
  static const startNap = 'startNap';
  static const startFocus = 'startFocus';

  /// Handles commands arriving while the app is alive. Call once at startup.
  static void bind() {
    if (kIsWeb) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'widgetCommand') {
        await apply(call.arguments as String? ?? '');
      }
      return null;
    });
  }

  /// Applies anything queued while the app was not running.
  static Future<void> drainPending() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pendingKey);
      if (raw == null || raw.isEmpty) return;

      await prefs.remove(_pendingKey);

      final commands = (jsonDecode(raw) as List).cast<String>();
      for (final command in commands) {
        await apply(command);
      }
    } catch (e) {
      debugPrint('WidgetCommandService.drainPending failed: $e');
    }
  }

  static Future<void> apply(String command) async {
    try {
      // Commands that carry arguments arrive as a JSON object rather than a
      // bare name — see AlarmIntentActivity.kt.
      if (command.startsWith('{')) {
        await _applyStructured(command);
        await WidgetSyncService.refresh();
        return;
      }

      switch (command) {
        case toggleNext:
          await _toggleNextAlarm();
        case snooze:
          final ringingId = AlarmRingFlow.currentRingingId;
          if (ringingId == 0) return;
          await AlarmRingFlow.snoozeAlarm(ringingId);
        case dismissAlarm:
          final ringingId = AlarmRingFlow.currentRingingId;
          if (ringingId == 0) return;
          await AlarmRingFlow.stopAlarm(ringingId);
          AlarmRingFlow.completeRingScreenDismiss();
        case resync:
          await AlarmService.resyncSchedules();
        case showAlarms:
        case newAlarm:
          _push(AlarmsScreen.routeName);
        case startNap:
          _push(NapTimerScreen.routeName);
        case startFocus:
          _push(FocusTimerScreen.routeName);
        default:
          debugPrint('WidgetCommandService: unknown command "$command"');
          return;
      }
      await WidgetSyncService.refresh();
    } catch (e) {
      debugPrint('WidgetCommandService.apply($command) failed: $e');
    }
  }

  /// Creates the alarm described by a system SET_ALARM intent.
  ///
  /// Writes through [AlarmService] directly rather than the Riverpod notifier,
  /// matching how [_toggleNextAlarm] already applies external commands.
  static Future<void> _applyStructured(String raw) async {
    final payload = jsonDecode(raw) as Map<String, dynamic>;
    if (payload['cmd'] != setAlarm) {
      debugPrint('WidgetCommandService: unknown structured command $raw');
      return;
    }

    final hour = payload['hour'] as int? ?? -1;
    // The caller named no time ("set an alarm" with nothing else). Opening the
    // editor is right here — inventing a time would be worse than asking.
    if (hour < 0 || hour > 23) {
      _push(AlarmsScreen.routeName);
      return;
    }

    final days = (payload['days'] as List?)?.cast<int>() ?? const <int>[];
    final alarm = AlarmService.createAlarm(
      time: TimeOfDay(hour: hour, minute: payload['minute'] as int? ?? 0),
      label: (payload['label'] as String?)?.trim().isNotEmpty == true
          ? payload['label'] as String
          : 'Alarm',
      repeatDays: days,
      isEnabled: true,
      tag: 'Voice',
    );

    await AlarmService.saveAlarm(alarm);
    await AlarmService.scheduleAlarm(alarm);

    if (payload['skipUi'] != true) {
      _push(AlarmsScreen.routeName);
    }
  }

  static void _push(String routeName) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushNamed(routeName);
  }

  /// Flips the soonest upcoming alarm on or off.
  static Future<void> _toggleNextAlarm() async {
    final alarms = AlarmService.getAllAlarms();
    if (alarms.isEmpty) return;

    final now = DateTime.now();
    final enabled = alarms.where((a) => a.isEnabled).toList();

    if (enabled.isNotEmpty) {
      enabled.sort(
        (a, b) => a.nextDateTimeFrom(now).compareTo(b.nextDateTimeFrom(now)),
      );
      await AlarmService.toggleAlarm(enabled.first.id, false);
      return;
    }

    // Nothing armed: re-arm whichever alarm comes round soonest.
    final candidates = [...alarms]..sort(
        (a, b) => a.nextDateTimeFrom(now).compareTo(b.nextDateTimeFrom(now)),
      );
    await AlarmService.toggleAlarm(candidates.first.id, true);
  }
}
