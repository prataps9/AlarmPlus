import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// Fixed colors that ignore the active brightness.
///
/// Prefer `Theme.of(context).colorScheme` or `context.semantics` — anything
/// reading these will not adapt to dark mode.
@Deprecated('Use ColorScheme roles or AppSemantics instead; see core/theme/')
class AppColors {
  static const Color primary = Palette.slate900;
  static const Color secondary = Palette.green500;
  static const Color slate600 = Palette.slate600;
  static const Color slate700 = Palette.slate700;
  static const Color slate200 = Palette.slate200;
  static const Color slate300 = Palette.slate300;
  static const Color slate400 = Palette.slate400;
  static const Color slate100 = Palette.slate100;
  static const Color slate50 = Palette.slate50;
}

// Durations
class AppDurations {
  static const Duration focusTimerDefault = Duration(minutes: 25);
  static const Duration snoozeTime = Duration(minutes: 5);
  static const Duration alarmFadeDuration = Duration(seconds: 8);
  static const Duration animationDuration = Duration(milliseconds: 280);
  static const Duration vibrationPattern1 = Duration(milliseconds: 500);
  static const Duration vibrationPattern2 = Duration(milliseconds: 1000);
}

// Animations
class AppAnimations {
  static const Duration splashDuration = Duration(milliseconds: 1800);
  static const Duration fadeInDuration = Duration(milliseconds: 280);
  static const Curve fadeCurve = Curves.easeOut;
}

// Alarm-specific
class AlarmDefaults {
  static const String soundDefault = 'default';
  static const String tagDefault = 'Steady wake';
  static const String labelDefault = 'Work Morning';
  static const int defaultHour = 7;
  static const int defaultMinute = 30;
}

/// Superseded by [Spacing] and [Radii] in core/theme/app_tokens.dart.
@Deprecated('Use Spacing and Radii from core/theme/app_tokens.dart')
class AppDimensions {
  static const double paddingSmall = Spacing.sm;
  static const double paddingMedium = Spacing.md;
  static const double paddingLarge = Spacing.lg;
  static const double paddingXLarge = Spacing.xl;
  static const double paddingXXLarge = Spacing.xxl;

  static const double radiusSmall = Radii.sm;
  static const double radiusMedium = Radii.md;
  static const double radiusLarge = Radii.xl;

  static const double iconSizeMedium = 30;
}

/// Superseded by [Tracking] in core/theme/app_tokens.dart.
@Deprecated('Use Tracking from core/theme/app_tokens.dart')
class AppTextStyles {
  static const double letterSpacingTitle = Tracking.eyebrow;
  static const double letterSpacingLabel = 1;
}

// Repeat days presets
class RepeatDaysPresets {
  static const List<int> daily = [1, 2, 3, 4, 5, 6, 7];
  static const List<int> weekdays = [1, 2, 3, 4, 5];
  static const List<int> weekends = [6, 7];
}
