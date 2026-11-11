import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/core/services/storage_service.dart';
import 'package:alarm_plus/core/services/system_alarm_request.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/core/startup.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';

/// System events Android delivers with the app closed (a timezone change, a
/// location alarm's arrival). The native receivers hand them to the running
/// app through [NativeControls] or, when it isn't running, start a short
/// background engine at `backgroundMain` (main.dart) that calls [runTask].
class BackgroundTasks {
  BackgroundTasks._();

  static const timezoneChanged = 'timezoneChanged';
  static const geofenceEntered = 'geofenceEntered';
  static const skipUpcoming = 'skipUpcoming';
  static const setAlarm = 'setAlarm';

  static const _channel = MethodChannel('alarmplus/background');

  /// Lets the running app handle the same events directly.
  static void bindForegroundHandlers() {
    NativeControls.register(timezoneChanged, (_) async {
      await followTimezone(force: true);
      return null;
    });
    NativeControls.register(setAlarm, (args) async {
      await _setAlarm(_ids(args));
      return null;
    });
    NativeControls.register(skipUpcoming, (args) async {
      await _skip(_ids(args));
      return null;
    });
    NativeControls.register(geofenceEntered, (args) async {
      await LocationAlarmService.handleArrivals(_ids(args));
      return null;
    });
  }

  /// Entry for the background engine: [args] is the task name, then its
  /// arguments. Always tells native it's done, so the engine is released.
  static Future<void> runTask(List<String> args) async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      if (args.isEmpty) return;
      await runStartupStep('storage', StorageService.init);
      await runStartupStep('settings', AppSettings.load);
      await runStartupStep('alarm engine', AlarmService.init);
      switch (args.first) {
        case timezoneChanged:
          await runStartupStep(
            'follow timezone',
            () => followTimezone(force: true),
            timeout: const Duration(seconds: 15),
          );
        case geofenceEntered:
          await runStartupStep(
            'location arrival',
            () => LocationAlarmService.handleArrivals(args.sublist(1)),
            timeout: const Duration(seconds: 15),
          );
        case setAlarm:
          await runStartupStep(
            'set alarm',
            () => _setAlarm(args.sublist(1)),
            timeout: const Duration(seconds: 15),
          );
        case skipUpcoming:
          await runStartupStep(
            'skip upcoming',
            () => _skip(args.sublist(1)),
            timeout: const Duration(seconds: 15),
          );
        default:
          debugPrint('BackgroundTasks: unknown task ${args.first}');
      }
    } finally {
      try {
        await _channel.invokeMethod<void>('done');
      } catch (e) {
        debugPrint('BackgroundTasks: could not report done: $e');
      }
    }
  }

  /// After travelling, move every alarm and reminder to the new local time.
  /// [force] skips the "did the zone change?" check: a fresh background
  /// isolate has no previous zone to compare with, and the OS has just said
  /// it changed.
  static Future<void> followTimezone({bool force = false}) async {
    final changed = force
        ? await AlarmService.rescheduleForCurrentTimezone()
        : await AlarmService.rescheduleIfTimezoneChanged();
    if (!changed) return;
    final bedtime = await BedtimeService.load();
    if (bedtime != null) await BedtimeService.save(bedtime);
    await StreakReminderService.refresh();
  }

  /// The live countdown's Skip button: skip that ring (or switch a one-off off).
  static Future<void> _skip(List<String> ids) async {
    for (final id in ids.map(int.tryParse).whereType<int>()) {
      await AlarmService.dismissUpcoming(id);
    }
  }

  /// A `SET_ALARM` intent (Assistant, Wear OS...): [args] is one JSON map.
  static Future<void> _setAlarm(List<String> args) async {
    if (args.isEmpty) return;
    try {
      final request = SystemAlarmRequest.parse(
          Map<String, dynamic>.from(jsonDecode(args.first) as Map));
      if (request == null) {
        debugPrint('BackgroundTasks: ignored a SET_ALARM with no valid time');
        return;
      }
      await request.apply();
    } catch (e) {
      debugPrint('BackgroundTasks: SET_ALARM failed: $e');
    }
  }

  static List<String> _ids(Object? args) =>
      args is List ? args.whereType<String>().toList() : const [];
}
