import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// Applies commands raised outside the app — home-screen widget buttons and
/// the Quick Settings tile.
///
/// Alarm state lives in Hive, which the native side can't touch, so those
/// surfaces hand a command here instead. Two delivery routes, matching
/// `WidgetCommandBridge.kt`: a live method call when the app is running, and a
/// prefs-backed queue drained at startup when it isn't.
class WidgetCommandService {
  WidgetCommandService._();

  static const _pendingKey = 'widget_pending_commands';

  static const toggleNext = 'toggleNext';
  static const snooze = 'snooze';

  /// Handles commands arriving while the app is alive. Call once at startup.
  static void bind() {
    if (kIsWeb) return;
    NativeControls.register('widgetCommand', (args) async {
      await apply(args as String? ?? '');
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
      switch (command) {
        case toggleNext:
          await _toggleNextAlarm();
        case snooze:
          final ringingId = AlarmRingFlow.currentRingingId;
          if (ringingId == 0) return;
          // Like volume keys and the notification: Hardcore alarms can only
          // be snoozed from the ring screen.
          if (AlarmService.findByIntId(ringingId)?.hardcoreMode == true) return;
          await AlarmRingFlow.snoozeAlarm(ringingId);
        default:
          debugPrint('WidgetCommandService: unknown command "$command"');
          return;
      }
      await WidgetSyncService.refresh();
    } catch (e) {
      debugPrint('WidgetCommandService.apply($command) failed: $e');
    }
  }

  /// Flips the soonest upcoming alarm on or off.
  static Future<void> _toggleNextAlarm() async {
    final alarms = AlarmService.getAllAlarms();
    if (alarms.isEmpty) return;

    final now = DateTime.now();
    // The same alarm the widget label shows, so a hidden nap/arrival alarm or
    // an expired one-off is never what gets switched off.
    final next = WidgetSyncService.nextWidgetAlarm(alarms, now);
    if (next != null) {
      await AlarmService.toggleAlarm(next.id, false);
      return;
    }

    // Nothing visible armed: re-arm whichever alarm comes round soonest. A dated
    // one-off whose day has gone sorted first forever, and re-arming it just
    // switched it straight off again, so the toggle did nothing.
    final candidates = [
      for (final a in alarms)
        if (!a.isExpiredAt(now) && !a.isSystem) a,
    ];
    if (candidates.isEmpty) return;
    candidates.sort(
        (a, b) => a.nextDateTimeFrom(now).compareTo(b.nextDateTimeFrom(now)),
      );
    await AlarmService.toggleAlarm(candidates.first.id, true);
  }
}
