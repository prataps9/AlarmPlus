import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/widgets/next_alarm_capsule.dart';

AlarmModel _alarm(int hour, {bool on = true, String label = 'Gym'}) => AlarmModel(
      id: 'a$hour',
      time: TimeOfDay(hour: hour, minute: 0),
      label: label,
      tag: '',
      sound: 'default',
      isEnabled: on,
      repeatDays: const [1, 2, 3, 4, 5, 6, 7],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('countdown wording: days, hours, then mm:ss inside the last hour', () {
    String f(Duration d) => NextAlarmCapsule.formatCountdown(d);
    expect(f(const Duration(days: 1, hours: 3, minutes: 5)), '1d 3h');
    expect(f(const Duration(hours: 7, minutes: 20)), '7h 20m');
    expect(f(const Duration(hours: 2, minutes: 5)), '2h 05m');
    expect(f(const Duration(minutes: 42, seconds: 9)), '42:09');
    expect(f(const Duration(seconds: 5)), '00:05');
    expect(f(const Duration(seconds: -3)), '00:00');
  });

  test('ring fills only over the last window', () {
    const w = Duration(hours: 2);
    expect(NextAlarmCapsule.progress(const Duration(hours: 5), w), 0);
    expect(NextAlarmCapsule.progress(const Duration(hours: 1), w), 0.5);
    expect(NextAlarmCapsule.progress(Duration.zero, w), 1);
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('renders at 320dp (dark: $dark, text x$scale)', (tester) async {
        tester.view.physicalSize = const Size(640, 1400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(
                size: const Size(320, 700), textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(22),
                child: NextAlarmCapsule(alarms: [_alarm(7), _alarm(9)]),
              ),
            ),
          ),
        ));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull);
        expect(find.text('NEXT ALARM'), findsOneWidget);
        expect(find.textContaining('Gym'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('a long label never squeezes the countdown on a narrow phone',
      (tester) async {
    // A fixed-width right column once left the countdown column ~10px wide,
    // so "NEXT ALARM" wrapped letter by letter and the row overflowed.
    tester.view.physicalSize = const Size(640, 1400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 700)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(22),
            child: NextAlarmCapsule(
                alarms: [_alarm(7, label: 'A very long alarm label that goes on')]),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 150));
    }
    expect(tester.takeException(), isNull);
    final caption = tester.getSize(find.text('NEXT ALARM'));
    expect(caption.height, lessThan(20), reason: 'caption stays on one line');
    expect(caption.width, greaterThan(60));
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('says so when there is no alarm', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(body: NextAlarmCapsule(alarms: []))));
    await tester.pump();
    expect(find.textContaining('No alarm set'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
