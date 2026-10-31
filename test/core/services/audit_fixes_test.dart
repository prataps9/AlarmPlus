import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

String _key(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

AlarmModel _daily(int hour, {bool on = true}) => AlarmModel(
      id: 'a$hour',
      time: TimeOfDay(hour: hour, minute: 0),
      label: '',
      tag: '',
      sound: 'default',
      isEnabled: on,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('quick add understands what people type and say', () {
    String? parse(String s) {
      final p = SmartAlarmService.parseQuickAdd(s);
      return p == null ? null : '${p.hour24}:${p.minute}';
    }

    test('voice typing writes "p.m." — that is 19:30, not 7:30', () {
      expect(parse('7:30 p.m.'), '19:30');
      expect(parse('6:15 a.m. gym'), '6:15');
      expect(parse('7:30 PM'), '19:30');
    });

    test('hour-only and named times', () {
      expect(parse('7am'), '7:0');
      expect(parse('12am'), '0:0');
      expect(parse('12 pm'), '12:0');
      expect(parse('noon'), '12:0');
      expect(parse('midnight'), '0:0');
      expect(parse('tomorrow 6'), '6:0');
      expect(parse('wake me at 9'), '9:0');
    });

    test('24-hour times still work', () {
      expect(parse('0:00'), '0:0');
      expect(parse('18.45'), '18:45');
      expect(parse('12:30 pm'), '12:30');
    });

    test('impossible times are rejected, not clamped', () {
      expect(parse('7:75'), isNull);
      expect(parse('24:00'), isNull);
      expect(parse('13 pm'), isNull);
      expect(parse('gym'), isNull);
    });

    test('"tomorrow" still sets the day offset', () {
      expect(SmartAlarmService.parseQuickAdd('tomorrow 6')!.dayOffset, 1);
    });
  });

  test('comeback bonus is paid after a break of 3+ days', () async {
    final now = DateTime.now();
    SharedPreferences.setMockInitialValues({
      'smart.alarm.stats': jsonEncode({'currentStreak': 0, 'dismissCount': 3}),
      'smart.streak.dismiss_history': jsonEncode({
        for (final ago in [12, 11, 10])
          _key(DateTime(now.year, now.month, now.day - ago)): true,
      }),
    });
    final reward = await SmartAlarmService.recordDismissed();
    expect(reward.comebackBonus, 100);
  });

  test('a mission pays its XP once, however fast it is tapped', () async {
    final missions = await SmartAlarmService.getTodayMissions();
    final id = missions.first.id;
    final first = await SmartAlarmService.completeMission(id);
    final second = await SmartAlarmService.completeMission(id);
    expect(first, greaterThan(0));
    expect(second, 0);
  });

  group('streak-at-risk reminder looks ahead from 9 pm, not from now', () {
    // Wed 22 Oct 2025, the 21:00 reminder slot.
    final ninePm = DateTime(2025, 10, 22, 21);

    test('a daily 7:00 alarm is coming, so no warning', () {
      expect(
          StreakReminderService.hasAlarmAfter(ninePm, alarms: [_daily(7)]),
          isTrue);
    });

    test('no alarm on, or only one at 18:00 tomorrow, means warn', () {
      expect(
          StreakReminderService.hasAlarmAfter(ninePm,
              alarms: [_daily(7, on: false)]),
          isFalse);
      expect(
          StreakReminderService.hasAlarmAfter(ninePm, alarms: [_daily(18)]),
          isFalse);
    });
  });
}
