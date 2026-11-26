import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester,
      {required double width, double scale = 1.0, bool use24h = false}) async {
    tester.view.physicalSize = Size(width * 2, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    // Opened with no alarm: the "preview" the Settings screen offers.
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 800),
          textScaler: TextScaler.linear(scale),
          alwaysUse24HourFormat: use24h,
        ),
        child: const AlarmRingScreen(),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  void finish(WidgetTester tester) {
    // Dispose the screen so its clock and animation timers stop.
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('shows the label and the two stock buttons', (tester) async {
    await open(tester, width: 412);
    finish(tester);
    expect(find.text('Alarm'), findsOneWidget);
    expect(find.text('Snooze'), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('5 min'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final use24h in [false, true]) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('fits 320dp (24h: $use24h, text x$scale)', (tester) async {
        await open(tester, width: 320, scale: scale, use24h: use24h);
        finish(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Stop'), findsOneWidget);
      });
    }
  }
}
