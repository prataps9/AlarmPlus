import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

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
