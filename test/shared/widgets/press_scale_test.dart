import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/shared/widgets/press_scale.dart';

void main() {
  double scaleOf(WidgetTester tester) =>
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;

  testWidgets('sinks while pressed, returns on release, and still taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressScale(
            child: InkWell(
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 60),
            ),
          ),
        ),
      ),
    ));
    expect(scaleOf(tester), 1);

    final gesture = await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump();
    expect(scaleOf(tester), lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(scaleOf(tester), 1);
    expect(taps, 1, reason: 'the child keeps its own tap');
  });

  testWidgets('does nothing when the system asks for less motion', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: PressScale(child: SizedBox(width: 10, height: 10)),
      ),
    ));
    expect(find.byType(AnimatedScale), findsNothing);
  });
}
