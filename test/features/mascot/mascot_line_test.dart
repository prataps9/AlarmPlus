import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/mascot/models/mascot_line.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/services/mascot_service.dart';

MascotLine _greet({
  int hour = 14,
  int streak = 3,
  bool hasUpcomingAlarm = true,
  int nextMilestone = 7,
  String? nextAlarmLabel = '07:00 AM',
}) {
  return MascotLines.homeGreeting(
    now: DateTime(2026, 9, 25, hour),
    streak: streak,
    hasUpcomingAlarm: hasUpcomingAlarm,
    nextMilestone: nextMilestone,
    nextAlarmLabel: nextAlarmLabel,
  );
}

void main() {
  group('MascotLines.homeGreeting', () {
    test('a streak with no alarm protecting it is the top priority', () {
      final line = _greet(hour: 23, streak: 5, hasUpcomingAlarm: false);
      expect(line.mood, MascotMood.worried);
      expect(line.text, contains('5-day streak'));
    });

    test('brand-new users get a waving introduction', () {
      final line = _greet(streak: 0, hasUpcomingAlarm: false);
      expect(line.mood, MascotMood.waving);
      expect(line.text, contains("I'm Pip"));
    });

    test('late at night Pip is sleepy and names the next alarm', () {
      final line = _greet(hour: 23);
      expect(line.mood, MascotMood.sleepy);
      expect(line.text, contains('07:00 AM'));
    });

    test('one day before a milestone Pip is proud', () {
      final line = _greet(streak: 6, nextMilestone: 7);
      expect(line.mood, MascotMood.proud);
      expect(line.text, contains('7-day milestone'));
    });

    test('mornings are a cheer', () {
      expect(_greet(hour: 8).mood, MascotMood.cheering);
      expect(_greet(hour: 8, streak: 0).text, contains('day one'));
    });

    test('afternoons fall back to a happy all-set line', () {
      final line = _greet(hour: 15);
      expect(line.mood, MascotMood.happy);
      expect(line.text, contains('07:00 AM'));
    });
  });

  group('MascotService.resolveWorn', () {
    test('free users wearing a premium pick fall back to classic', () {
      expect(
        MascotService.resolveWorn(MascotOutfit.royal, isPro: false),
        MascotOutfit.classic,
      );
    });

    test('Pro users wear what they picked', () {
      expect(
        MascotService.resolveWorn(MascotOutfit.royal, isPro: true),
        MascotOutfit.royal,
      );
    });

    test('unknown stored names default to classic', () {
      expect(MascotOutfit.fromName('tuxedo'), MascotOutfit.classic);
      expect(MascotOutfit.fromName(null), MascotOutfit.classic);
    });
  });
}
