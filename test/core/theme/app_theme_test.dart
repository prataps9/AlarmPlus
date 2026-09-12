import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/core/theme/app_theme_ext.dart';

void main() {
  setUpAll(() {
    // The themes pull Space Grotesk / DM Sans through google_fonts, which
    // would otherwise try to download them over HTTP during tests.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('AppTheme', () {
    test('exposes AppSemantics in both brightnesses', () {
      expect(
        AppTheme.build(Brightness.light, useGoogleFonts: false)
            .extension<AppSemantics>(),
        isNotNull,
      );
      expect(
        AppTheme.build(Brightness.dark, useGoogleFonts: false)
            .extension<AppSemantics>(),
        isNotNull,
      );
    });

    test('light and dark actually differ on surface and text', () {
      final light = AppTheme.build(Brightness.light, useGoogleFonts: false);
      final dark = AppTheme.build(Brightness.dark, useGoogleFonts: false);

      expect(light.colorScheme.surface, isNot(dark.colorScheme.surface));
      expect(light.colorScheme.onSurface, isNot(dark.colorScheme.onSurface));
      expect(light.scaffoldBackgroundColor, light.colorScheme.surface);
      expect(dark.scaffoldBackgroundColor, dark.colorScheme.surface);
    });

    test('component themes follow the scheme rather than hardcoded white', () {
      final dark = AppTheme.build(Brightness.dark, useGoogleFonts: false);

      // Regression guard: cards and sheets used to be hardcoded Colors.white,
      // which made every card unreadable in dark mode.
      expect(dark.cardTheme.color, isNot(Colors.white));
      expect(dark.bottomSheetTheme.backgroundColor, isNot(Colors.white));
      expect(dark.appBarTheme.backgroundColor, dark.colorScheme.surface);
      expect(
        dark.floatingActionButtonTheme.backgroundColor,
        dark.colorScheme.primary,
      );
    });

    test('streakTier escalates with streak length', () {
      const s = AppSemantics.light;

      expect(s.streakTier(0), s.streakCold);
      expect(s.streakTier(3), s.streakWarm);
      expect(s.streakTier(7), s.streakHot);
      expect(s.streakTier(30), s.streakGold);
      expect(s.streakTier(365), s.streakGold);
    });
  });

  testWidgets('semantics extension is reachable from context', (tester) async {
    late AppSemantics resolved;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light, useGoogleFonts: false),
        home: Builder(
          builder: (context) {
            resolved = context.semantics;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolved.success, AppSemantics.light.success);
  });
}
