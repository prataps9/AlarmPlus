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

  testWidgets('swipe deletes straight away (the list offers Undo)',
      (tester) async {
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

    expect(find.byType(AlertDialog), findsNothing);
    expect(deleted, 1);
  });

  testWidgets('long-press opens more actions', (tester) async {
    var pressed = 0;
    await tester.pumpWidget(
      _host(AlarmCard(
        alarm: _alarm(),
        onToggle: (_) {},
        onTap: () {},
        onLongPress: () => pressed++,
      )),
    );

    await tester.longPress(find.byType(AlarmCard));
    expect(pressed, 1);
  });

  testWidgets('a paused alarm says until when, instead of Skip next',
      (tester) async {
    final now = DateTime.now();
    final until = DateTime(now.year, now.month, now.day + 5);
    await tester.pumpWidget(
      _host(AlarmCard(
        alarm: _alarm().copyWith(pausedUntil: until),
        onToggle: (_) {},
        onSkipNext: (_) {},
      )),
    );

    expect(find.textContaining('Paused until'), findsOneWidget);
    expect(find.text('Skip next'), findsNothing);
  });
}
