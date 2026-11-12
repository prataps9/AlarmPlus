import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/guardian_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/settings/screens/settings_screen.dart';

void main() {
  group('claimDailyXp', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('pays once per action per day', () async {
      final day = DateTime(2026, 10, 27, 8);
      expect(await SmartAlarmService.claimDailyXp('diary', now: day), isTrue);
      expect(await SmartAlarmService.claimDailyXp('diary', now: day), isFalse);
      // Other actions are tracked separately.
      expect(await SmartAlarmService.claimDailyXp('in_bed', now: day), isTrue);
      // A new day pays again.
      expect(
        await SmartAlarmService.claimDailyXp(
            'diary', now: DateTime(2026, 10, 28, 7)),
        isTrue,
      );
    });

    test('concurrent claims (double tap) pay once', () async {
      final day = DateTime(2026, 10, 27, 8);
      final results = await Future.wait([
        SmartAlarmService.claimDailyXp('check_in', now: day),
        SmartAlarmService.claimDailyXp('check_in', now: day),
      ]);
      expect(results.where((r) => r), hasLength(1));
    });
  });

  test('webhook URL must be https with a host', () {
    expect(GuardianService.isValidWebhookUrl('https://hooks.example.com/x'),
        isTrue);
    expect(GuardianService.isValidWebhookUrl('  https://a.b/c  '), isTrue);
    expect(GuardianService.isValidWebhookUrl('http://hooks.example.com'),
        isFalse);
    expect(GuardianService.isValidWebhookUrl('hello'), isFalse);
    expect(GuardianService.isValidWebhookUrl('https://'), isFalse);
    expect(GuardianService.isValidWebhookUrl(''), isFalse);
  });

  test('free users keep NONE and MATH; Pro challenges fall back to MATH', () {
    for (final type in DismissChallengeType.values) {
      expect(effectiveChallenge(type, isPro: true), type);
    }
    expect(effectiveChallenge(DismissChallengeType.none, isPro: false),
        DismissChallengeType.none);
    expect(effectiveChallenge(DismissChallengeType.math, isPro: false),
        DismissChallengeType.math);
    for (final type in DismissChallengeType.values.where(challengeNeedsPro)) {
      expect(effectiveChallenge(type, isPro: false), DismissChallengeType.math);
    }
  });
}
