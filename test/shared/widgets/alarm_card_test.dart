import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';

AlarmModel _alarm({bool isEnabled = true, String label = 'Work Morning'}) {
  return AlarmModel(
    id: 'a1',
    time: const TimeOfDay(hour: 6, minute: 30),
    label: label,
    tag: 'Steady wake',
    sound: 'default',
    isEnabled: isEnabled,
    repeatDays: const [1, 2, 3, 4, 5],
  );
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(Brightness.light, useGoogleFonts: false),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('tapping the card opens edit', (tester) async {
    var tapped = 0;

    await tester.pumpWidget(
      _host(
        AlarmCard(
          alarm: _alarm(),
          onToggle: (_) {},
          onTap: () => tapped++,
        ),
      ),
    );

    await tester.tap(find.byType(AlarmCard));
    await tester.pump();

    expect(tapped, 1);
  });

  testWidgets('renders time, label and repeat summary', (tester) async {
    await tester.pumpWidget(
      _host(AlarmCard(alarm: _alarm(), onToggle: (_) {})),
    );

    // The time is a RichText (time + period spans), not a plain Text.
    expect(find.textContaining('6:30', findRichText: true), findsOneWidget);
    expect(find.text('Work Morning'), findsOneWidget);
    expect(find.text('Steady wake'), findsOneWidget);
  });

  testWidgets('toggle reports the new value', (tester) async {
    bool? received;

    await tester.pumpWidget(
      _host(
        AlarmCard(
          alarm: _alarm(isEnabled: true),
          onToggle: (v) => received = v,
        ),
      ),
    );

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(received, isFalse);
  });

  testWidgets('has no delete affordance when onDelete is omitted',
      (tester) async {
    await tester.pumpWidget(
      _host(AlarmCard(alarm: _alarm(), onToggle: (_) {})),
    );

    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets('swipe-to-delete asks for confirmation first', (tester) async {
    var deleted = 0;

    await tester.pumpWidget(
      _host(
        AlarmCard(
          alarm: _alarm(),
          onToggle: (_) {},
          onDelete: () => deleted++,
        ),
      ),
    );

    await tester.drag(find.byType(AlarmCard), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Delete alarm?'), findsOneWidget);
    expect(deleted, 0, reason: 'must not delete before confirming');

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(deleted, 0);
  });
}
