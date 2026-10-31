import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

AlarmModel _alarm(
  String id,
  int hour, {
  bool enabled = true,
  String tag = 'work',
  DateTime? date,
}) =>
    AlarmModel(
      id: id,
      time: TimeOfDay(hour: hour, minute: 0),
      label: id,
      repeatDays: const [],
      isEnabled: enabled,
      tag: tag,
      sound: 'default',
      date: date,
    );

void main() {
  final now = DateTime(2026, 10, 27, 6);

  group('WidgetSyncService.nextWidgetAlarm', () {
    test('picks the soonest enabled alarm', () {
      final next = WidgetSyncService.nextWidgetAlarm([
        _alarm('late', 9),
        _alarm('off', 7, enabled: false),
        _alarm('early', 8),
      ], now);
      expect(next?.id, 'early');
    });

    test('skips hidden system alarms', () {
      final next = WidgetSyncService.nextWidgetAlarm([
        _alarm('nap', 6, tag: AlarmModel.napTag),
        _alarm('arrive', 6, tag: AlarmModel.locationTag),
        _alarm('real', 9),
      ], now);
      expect(next?.id, 'real');
    });

    test('skips expired dated one-offs', () {
      final next = WidgetSyncService.nextWidgetAlarm([
        _alarm('gone', 5, date: DateTime(2026, 10, 20)),
        _alarm('real', 9),
      ], now);
      expect(next?.id, 'real');
    });

    test('null when only hidden or expired alarms are enabled', () {
      final next = WidgetSyncService.nextWidgetAlarm([
        _alarm('nap', 6, tag: AlarmModel.napTag),
        _alarm('gone', 5, date: DateTime(2026, 10, 20)),
      ], now);
      expect(next, isNull);
    });
  });
}
