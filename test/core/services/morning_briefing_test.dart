import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/morning_briefing_service.dart';
import 'package:alarm_plus/core/services/native_controls.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> calls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls = [];
    messenger.setMockMethodCallHandler(NativeControls.channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(NativeControls.channel, null));

  test('reads the time, day, wake-up speed, streak and score', () {
    final text = MorningBriefingService.compose(
      now: DateTime(2026, 10, 28, 7, 5),
      dismissSeconds: 34,
      streakDays: 5,
      wakeScore: 82,
    );
    expect(text, startsWith('Good morning. It is 7:05'));
    expect(text, contains('Wednesday 28 October'));
    expect(text, contains('You were up in 34 seconds.'));
    expect(text, contains('5 day streak'));
    expect(text, contains('wake score is 82'));
  });

  test('no streak line for a first day, minutes for slow wake-ups', () {
    final text = MorningBriefingService.compose(
      now: DateTime(2026, 10, 28, 13, 0),
      dismissSeconds: 150,
      streakDays: 1,
      wakeScore: 40,
    );
    expect(text, startsWith('Good afternoon'));
    expect(text, contains('3 minutes'));
    expect(text, isNot(contains('streak')));
  });

  test('silent unless switched on', () async {
    await MorningBriefingService.playIfEnabled(
        dismissSeconds: 10, streakDays: 2, wakeScore: 90);
    expect(calls, isEmpty);

    await MorningBriefingService.setEnabled(true);
    await MorningBriefingService.playIfEnabled(
        dismissSeconds: 10, streakDays: 2, wakeScore: 90);
    expect(calls.single.method, 'speak');
    expect((calls.single.arguments as Map)['text'], contains('Good'));
  });
}
