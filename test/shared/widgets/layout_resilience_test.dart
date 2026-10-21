import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';
import 'package:alarm_plus/shared/widgets/stat_tile.dart';

AlarmModel _alarm({List<int> days = const [1, 2, 3, 4, 5], String tag = 'Steady wake'}) =>
    AlarmModel(
      id: 'a',
      time: const TimeOfDay(hour: 6, minute: 30),
      label: 'Work Morning',
      tag: tag,
      sound: 'default',
      isEnabled: true,
      repeatDays: days,
    );

/// A small phone with large system text: the combination that used to
/// overflow Home, the alarm card and the Insights tiles.
Future<void> _pumpSmall(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(320 * 2, 640 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
      child: c!,
    ),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(22), child: child)),
  ));
}

void main() {
  group('alarm card at 320dp with 1.3x text', () {
    testWidgets('tag, repeat label and Skip next flow onto extra lines', (tester) async {
      await _pumpSmall(tester, AlarmCard(alarm: _alarm(), onToggle: (_) {}, onSkipNext: (_) {}));
      expect(tester.takeException(), isNull);
      // The label stays whole instead of breaking mid-word ("Week" / "days").
      expect(find.text('Weekdays'), findsOneWidget);
    });

    testWidgets('a long custom day list does not overflow', (tester) async {
      await _pumpSmall(
        tester,
        AlarmCard(
          alarm: _alarm(days: const [1, 2, 3, 5, 6, 7]),
          onToggle: (_) {},
          onSkipNext: (_) {},
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Mon, Tue, Wed, Fri, Sat, Sun'), findsOneWidget);
    });
  });

  testWidgets('stat tiles in content-sized rows survive large text', (tester) async {
    Widget row(Widget a, Widget b) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)],
          ),
        );
    await _pumpSmall(
      tester,
      row(
        const StatTile(label: 'Best streak', value: '12', caption: 'days', icon: Icons.emoji_events_rounded),
        const StatTile(label: 'On time', value: '340', caption: 'wake-ups', icon: Icons.check_circle_rounded),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
