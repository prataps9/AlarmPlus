import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alarm_plus/core/theme/app_theme_ext.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';

/// The app's light and dark themes.
///
/// Component themes are defined here rather than per-screen so a widget picks
/// up the right look by default. Screens that hardcode colors are bugs waiting
/// to happen in dark mode.
class AppTheme {
  const AppTheme._();

  static ThemeData get light => build(Brightness.light);
  static ThemeData get dark => build(Brightness.dark);

  /// [useGoogleFonts] exists so tests can build the theme without google_fonts
  /// reaching for the network. Production always leaves it true.
  static ThemeData build(Brightness brightness, {bool useGoogleFonts = true}) {
    final isDark = brightness == Brightness.dark;

    final colorScheme = isDark
        ? const ColorScheme.dark(
            primary: Palette.green500,
            onPrimary: Palette.slate900,
            secondary: Palette.slate400,
            onSecondary: Palette.slate900,
            surface: Palette.slate900,
            onSurface: Colors.white,
            surfaceContainer: Palette.slate800,
            surfaceContainerHighest: Palette.slate700,
            onSurfaceVariant: Palette.slate300,
            outline: Palette.slate600,
            outlineVariant: Palette.slate700,
            error: Palette.red500,
          )
        : const ColorScheme.light(
            primary: Palette.green600,
            onPrimary: Colors.white,
            secondary: Palette.slate500,
            onSecondary: Colors.white,
            surface: Colors.white,
            onSurface: Palette.slate900,
            surfaceContainer: Colors.white,
            surfaceContainerHighest: Palette.slate100,
            onSurfaceVariant: Palette.slate600,
            outline: Palette.slate300,
            outlineVariant: Palette.slate200,
            error: Palette.red500,
          );

    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;

    // Space Grotesk for display/headings, DM Sans for body — as before, except
    // headlineLarge is trimmed 44 -> 36 so the Insights hero doesn't eat the
    // whole viewport.
    TextStyle heading({
      required double size,
      required FontWeight weight,
      required Color color,
      double? letterSpacing,
    }) {
      return useGoogleFonts
          ? GoogleFonts.spaceGrotesk(
              fontSize: size,
              fontWeight: weight,
              color: color,
              letterSpacing: letterSpacing,
            )
          : TextStyle(
              fontSize: size,
              fontWeight: weight,
              color: color,
              letterSpacing: letterSpacing,
            );
    }

    TextStyle body({
      required double size,
      FontWeight? weight,
      required Color color,
      double? letterSpacing,
    }) {
      return useGoogleFonts
          ? GoogleFonts.dmSans(
              fontSize: size,
              fontWeight: weight,
              color: color,
              letterSpacing: letterSpacing,
            )
          : TextStyle(
              fontSize: size,
              fontWeight: weight,
              color: color,
              letterSpacing: letterSpacing,
            );
    }

    final baseTextTheme =
        useGoogleFonts ? GoogleFonts.dmSansTextTheme() : const TextTheme();

    final textTheme = baseTextTheme.copyWith(
      headlineLarge: heading(
        size: 36,
        weight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      headlineMedium: heading(
        size: 28,
        weight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      headlineSmall: heading(size: 22, weight: FontWeight.w700, color: onSurface),
      titleLarge: heading(size: 20, weight: FontWeight.w700, color: onSurface),
      titleMedium: heading(size: 16, weight: FontWeight.w600, color: onSurface),
      bodyLarge: body(size: 17, weight: FontWeight.w500, color: onSurface),
      bodyMedium: body(size: 15, color: onSurfaceVariant),
      bodySmall: body(size: 13, color: onSurfaceVariant),
      labelLarge: body(size: 14, weight: FontWeight.w600, color: onSurface),
      // The tracked "eyebrow" label used above sections.
      labelSmall: body(
        size: 11,
        weight: FontWeight.w700,
        color: onSurfaceVariant,
        letterSpacing: Tracking.eyebrow,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme,
      extensions: [isDark ? AppSemantics.dark : AppSemantics.light],
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: Radii.cardRadius,
          side: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle:
            textTheme.labelLarge?.copyWith(color: colorScheme.onPrimary),
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(Radii.pill)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        hintStyle: textTheme.bodyMedium,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          foregroundColor: onSurface,
          side: BorderSide(color: colorScheme.outline),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? textTheme.labelSmall?.copyWith(
                  letterSpacing: Tracking.label,
                  color: colorScheme.primary,
                )
              : textTheme.labelSmall?.copyWith(letterSpacing: Tracking.label),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        unselectedIconTheme: IconThemeData(color: onSurfaceVariant),
        selectedLabelTextStyle:
            textTheme.labelLarge?.copyWith(color: colorScheme.primary),
        unselectedLabelTextStyle: textTheme.bodySmall,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: colorScheme.surface,
        showDragHandle: true,
        dragHandleColor: colorScheme.outline,
        shape: const RoundedRectangleBorder(borderRadius: Radii.sheetRadius),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: Spacing.xxl,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: onSurfaceVariant,
        titleTextStyle: textTheme.bodyLarge,
        subtitleTextStyle: textTheme.bodySmall,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceContainerHighest,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.onPrimary
              : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colorScheme.primary
              : null,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? Palette.slate700 : Palette.slate900,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
    );
  }
}
