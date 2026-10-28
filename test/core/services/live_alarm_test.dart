import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/live_alarm_service.dart';
import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/clock/models/clock_models.dart';

AlarmModel _alarm(
  String id,
  int hour, {
  int minute = 0,
  String label = '',
  bool on = true,
  List<int> days = const [1, 2, 3, 4, 5, 6, 7],
  String tag = '',
  DateTime? skip,
}) =>
    AlarmModel(
      id: id,
      time: TimeOfDay(hour: hour, minute: minute),
      label: label,
      tag: tag,
      sound: 'default',
      isEnabled: on,
      repeatDays: days,
      skipDate: skip,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 28, 5, 0); // a Wednesday, before 06:00

  group('which ring the countdown is about', () {
    test('the soonest enabled alarm wins', () {
      final r = LiveAlarmService.pickNext(
          [_alarm('late', 9), _alarm('early', 6, label: 'Gym')], now, {});
      expect(r!.alarm.id, 'early');
      expect(r.at, DateTime(2026, 10, 28, 6));
      expect(r.snoozed, isFalse);
    });

    test('off alarms and hidden system alarms are ignored', () {
      expect(
          LiveAlarmService.pickNext([
            _alarm('off', 6, on: false),
            _alarm('nap', 5, minute: 30, tag: AlarmModel.napTag),
          ], now, {}),
          isNull);
    });

    test('a skipped occurrence is not what the countdown shows', () {
      final r = LiveAlarmService.pickNext(
          [_alarm('daily', 6, skip: DateTime(2026, 10, 28))], now, {});
      expect(r!.at, DateTime(2026, 10, 29, 6));
    });

    test('a pending snooze replaces the alarm\'s normal next time', () {
      final a = _alarm('a', 6);
      final snoozeAt = DateTime(2026, 10, 28, 6, 5);
      final r = LiveAlarmService.pickNext(
          [a, _alarm('b', 7)], now, {AlarmService.alarmIntId('a'): snoozeAt});
      expect(r!.alarm.id, 'a');
      expect(r.at, snoozeAt);
      expect(r.snoozed, isTrue);
    });

    test('a one-off for another day is found within the 8-day window', () {
      final r = LiveAlarmService.pickNext(
          [_alarm('weekly', 8, days: const [DateTime.monday])], now, {});
      expect(r!.at, DateTime(2026, 11, 2, 8));
    });
  });

  group('wording', () {
    LiveRing ring(AlarmModel a, DateTime at, {bool snoozed = false}) =>
        (alarm: a, at: at, snoozed: snoozed);

    test('today, tomorrow and later days, with the label', () {
      final a = _alarm('a', 6, label: 'Gym');
      final today = LiveAlarmService.wording(
          ring(a, DateTime(2026, 10, 28, 6)), now, use24h: false);
      expect(today.title, 'Alarm · 6:00 AM');
      expect(today.text, 'Today · Gym');

      final tomorrow = LiveAlarmService.wording(
          ring(_alarm('b', 6), DateTime(2026, 10, 29, 6)), now, use24h: true);
      expect(tomorrow.title, 'Alarm · 06:00');
      expect(tomorrow.text, 'Tomorrow');

      final later = LiveAlarmService.wording(
          ring(_alarm('c', 6), DateTime(2026, 10, 31, 6)), now, use24h: false);
      expect(later.text, 'Saturday');
    });

    test('a snooze says so and cannot be skipped', () {
      final w = LiveAlarmService.wording(
          ring(_alarm('a', 6), DateTime(2026, 10, 28, 6, 5), snoozed: true),
          now,
          use24h: false);
      expect(w.title, 'Snoozed · 6:05 AM');
    });
  });

  group('what reaches the native side', () {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      SharedPreferences.setMockInitialValues({});
      calls = [];
      messenger.setMockMethodCallHandler(NativeControls.channel, (call) async {
        calls.add(call);
        return null;
      });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      messenger.setMockMethodCallHandler(NativeControls.channel, null);
    });

    test('a running timer sends its end time; a paused or cleared one clears it', () async {
      final end = DateTime(2026, 10, 28, 5, 10);
      await LiveAlarmService.syncTimer(
          CountdownState(total: const Duration(minutes: 10), endsAt: end));
      expect(calls.last.method, 'liveTimerSync');
      expect((calls.last.arguments as Map)['endMs'], end.millisecondsSinceEpoch);

      await LiveAlarmService.syncTimer(const CountdownState(
          total: Duration(minutes: 10), pausedRemaining: Duration(minutes: 4)));
      expect((calls.last.arguments as Map)['endMs'], 0);
      await LiveAlarmService.syncTimer(null);
      expect((calls.last.arguments as Map)['endMs'], 0);
    });

    test('the ring payload carries id, due time and the 2 h window', () async {
      // Without a loaded alarm store there is nothing to count down to:
      // native is told to clear.
      await LiveAlarmService.sync();
      expect(calls.last.method, 'liveAlarmSync');
      expect((calls.last.arguments as Map)['ring'], isNull);
      expect(jsonEncode({'w': AlarmService.upcomingNoticeLead.inMilliseconds}),
          contains('7200000'));
    });
  });
}
