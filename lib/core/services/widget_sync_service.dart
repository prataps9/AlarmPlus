import 'dart:async';

import 'package:alarm/alarm.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'package:alarm_plus/core/services/live_alarm_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

/// Keeps the Android home screen widget (`AlarmWidgetProvider.kt`) in sync
/// with the current streak and next scheduled alarm. Call [refresh] after
/// anything that changes either value — alarm scheduling/cancelling/toggling,
/// or a dismiss/miss that changes the streak.
///
/// No iOS counterpart yet: that needs a WidgetKit extension added in Xcode
/// (see ios/WIDGET_SETUP.md). `home_widget`'s Dart API is cross-platform, so
/// nothing here will need to change once that extension exists.
class WidgetSyncService {
  WidgetSyncService._();

  static const _androidWidgetName = 'AlarmWidgetProvider';

  /// Matches the `kind` of the future iOS WidgetKit extension (see
  /// ios/WIDGET_SETUP.md). Harmless to pass before that extension exists —
  /// `home_widget` simply finds no matching widget to reload on iOS today.
  static const _iosWidgetName = 'AlarmWidget';

  /// Must match the App Group configured on the iOS widget extension once it
  /// exists (see ios/WIDGET_SETUP.md). Safe to call on Android too — the
  /// plugin's Android side treats it as a no-op there.
  static const _iosAppGroupId = 'group.com.alarmplus.app';

  static Future<void> refresh() async {
    if (kIsWeb) return;
    // Same trigger points as the widget: anything that changes the next ring.
    unawaited(LiveAlarmService.sync());
    try {
      await HomeWidget.setAppGroupId(_iosAppGroupId);
      final stats = await SmartAlarmService.getStats();
      final next = nextWidgetAlarm(AlarmService.getAllAlarms(), DateTime.now());
      await HomeWidget.saveWidgetData<int>('streak_days', stats.currentStreak);
      await HomeWidget.saveWidgetData<String>('next_alarm', _label(next));
      // Drives the widget's toggle tint and the Quick Settings tile state.
      await HomeWidget.saveWidgetData<bool>('next_alarm_enabled', next != null);
      await HomeWidget.saveWidgetData<bool>('alarm_ringing', await _isRinging());
      await HomeWidget.updateWidget(
        androidName: _androidWidgetName,
        iOSName: _iosWidgetName,
      );
    } catch (e) {
      // Widget sync is best-effort — never let it break the calling flow
      // (alarm scheduling, dismissal, etc.) on devices/platforms where the
      // widget plugin isn't available.
      debugPrint('WidgetSyncService.refresh failed: $e');
    }
  }

  /// The alarm the widget and tile show and toggle: the soonest enabled one,
  /// skipping hidden system alarms (nap, arrival) and dated one-offs whose
  /// moment has passed. Those used to win the sort and label the widget with
  /// an alarm the user can't see or that will never ring.
  static AlarmModel? nextWidgetAlarm(
    Iterable<AlarmModel> alarms,
    DateTime now,
  ) {
    final candidates = [
      for (final a in alarms)
        if (a.isEnabled && !a.isSystem && !a.isExpiredAt(now)) a,
    ];
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => a.nextDateTimeFrom(now).compareTo(b.nextDateTimeFrom(now)),
    );
    return candidates.first;
  }

  /// Asks the alarm plugin rather than trusting [AlarmRingFlow.currentRingingId]
  /// alone: that id outlives a snooze, which left the widget's Snooze button
  /// live while nothing rang and dead during the re-ring.
  static Future<bool> _isRinging() async {
    final id = AlarmRingFlow.currentRingingId;
    if (id == 0) return false;
    try {
      return await Alarm.isRinging(id);
    } catch (_) {
      return false;
    }
  }

  static String _label(AlarmModel? next) {
    if (next == null) return 'No alarm set';
    return TimeFormat.clockLabel(
      next.time.hour,
      next.time.minute,
      use24h: WidgetsBinding.instance.platformDispatcher.alwaysUse24HourFormat,
    );
  }
}
