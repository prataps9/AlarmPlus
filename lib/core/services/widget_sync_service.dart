import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

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
    try {
      await HomeWidget.setAppGroupId(_iosAppGroupId);
      final stats = await SmartAlarmService.getStats();
      await HomeWidget.saveWidgetData<int>('streak_days', stats.currentStreak);
      await HomeWidget.saveWidgetData<String>('next_alarm', _nextAlarmLabel());
      // Drives the widget's toggle tint and the Quick Settings tile state.
      await HomeWidget.saveWidgetData<bool>(
        'next_alarm_enabled',
        AlarmService.getAllAlarms().any((a) => a.isEnabled),
      );
      await HomeWidget.saveWidgetData<bool>(
        'alarm_ringing',
        AlarmRingFlow.currentRingingId != 0,
      );
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

  static String _nextAlarmLabel() {
    final now = DateTime.now();
    final enabled = AlarmService.getAllAlarms().where((a) => a.isEnabled).toList();
    if (enabled.isEmpty) return 'No alarm set';

    enabled.sort(
      (a, b) => a.nextDateTimeFrom(now).compareTo(b.nextDateTimeFrom(now)),
    );
    final next = enabled.first;
    return '${next.timeLabel} ${next.periodLabel}';
  }
}
