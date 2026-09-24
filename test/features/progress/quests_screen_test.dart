import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/progression_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/features/progress/screens/quests_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final brightness in Brightness.values) {
    testWidgets('renders goal, quests and shop in ${brightness.name} mode', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(360, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.runAsync(() async {
        await SmartAlarmService.awardXp(40);
        await ProgressionService.addGems(120);
        await ProgressionService.activateBoost();
      });

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(brightness, useGoogleFonts: false),
        home: const QuestsScreen(),
      ));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();

      expect(find.text('Daily goal'), findsOneWidget);
      expect(find.text('40 / 100 XP · Regular'), findsOneWidget);
      expect(find.textContaining('Double XP active'), findsOneWidget);
      expect(find.text('Streak Freeze'), findsOneWidget);
      for (final q in ProgressionService.questsFor(DateTime.now())) {
        expect(find.text(q.title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
