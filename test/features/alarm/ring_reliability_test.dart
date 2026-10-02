import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/app_shortcuts_service.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/home/screens/splash_screen.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_sounds_screen.dart';
import 'package:alarm_plus/shared/widgets/alarm_logo.dart';

void main() {
  group('wake-up check timing', () {
    test('re-ring is exactly 60 s after the check, at second precision', () {
      // 07:00:40 — the old TimeOfDay(now + 5 s) rounded this down to 07:00,
      // which is in the past, so the re-ring slipped to the next day.
      final dismissed = DateTime(2026, 9, 25, 7, 0, 40);
      final t = wakeCheckTimes(dismissed, 10);
      expect(t.checkAt, DateTime(2026, 9, 25, 7, 10, 40));
      expect(t.reringAt, DateTime(2026, 9, 25, 7, 11, 40));
    });

    test('works across midnight', () {
      final t = wakeCheckTimes(DateTime(2026, 9, 25, 23, 55), 15);
      expect(t.reringAt, DateTime(2026, 9, 26, 0, 11));
    });

    test('check notification id cannot collide with the alarm id', () {
      expect(wakeCheckNotificationId(123), isNot(123));
    });
  });

  test('auto-silence comes after the 10-minute guardian alert', () {
    expect(autoSilenceAfter, greaterThan(const Duration(minutes: 10)));
  });

  test('every launcher shortcut points at a real named route', () {
    expect(AppShortcutsService.routes.values.toSet(), {
      AlarmsScreen.routeName,
      NapTimerScreen.routeName,
      SleepSoundsScreen.routeName,
      FocusTimerScreen.routeName,
    });
  });

  group('splash hand-off', () {
    testWidgets(
        'replacing the splash keeps a ring screen pushed above it',
        (tester) async {
      late BuildContext splashContext;
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        routes: {
          '/': (context) {
            splashContext = context;
            return const Text('SPLASH');
          },
          '/app': (_) => const Text('HOME'),
          '/ring': (_) => const Text('RING'),
        },
      ));
      // An alarm cold-started the app: its ring screen lands on top.
      navKey.currentState!.pushNamed('/ring');
      await tester.pumpAndSettle();

      replaceRouteInPlace(splashContext, '/app');
      await tester.pumpAndSettle();

      expect(find.text('RING'), findsOneWidget);
      expect(find.text('SPLASH', skipOffstage: false), findsNothing);
      navKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(find.text('HOME'), findsOneWidget);
    });

    testWidgets('logo paints with the minute hand at any angle',
        (tester) async {
      for (final turns in [0.0, 0.25, 1.0]) {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: AlarmLogo(size: 240, color: Colors.black, minuteTurns: turns),
          ),
        ));
      }
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a ringing Pip animates without errors', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Center(child: PipMascot(mood: MascotMood.sleepy, ringing: true)),
    ));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.takeException(), isNull);
  });
}
