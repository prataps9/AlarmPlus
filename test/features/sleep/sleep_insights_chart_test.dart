import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/features/sleep/models/sleep_entry.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/sleep/services/sleep_diary_service.dart';

void main() {
  testWidgets('quality chart draws with days missing from the diary',
      (tester) async {
    // Two logged days out of seven: the gaps used to be FlSpot(x, NaN),
    // which crashed fl_chart ("Offset argument contained a NaN value").
    SharedPreferences.setMockInitialValues({});
    final now = DateTime.now();
    for (final daysAgo in [0, 3]) {
      final d = DateTime(now.year, now.month, now.day - daysAgo);
      await SleepDiaryService.saveEntry(SleepEntry(
        date: SleepDiaryService.dateKey(d),
        sleepQuality: 4,
        morningMood: 3,
      ));
    }

    tester.view.physicalSize = const Size(412, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.build(Brightness.light, useGoogleFonts: false),
      home: const SleepInsightsScreen(),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Sleep Quality Trend'), findsOneWidget);
    expect(find.text('No diary entries yet — start logging!'), findsNothing);
  });
}
