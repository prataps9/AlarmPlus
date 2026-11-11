import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// Colours that carry meaning but have no slot in Material's [ColorScheme]:
/// success and danger, the streak flame ramp, and the chart series.
///
/// Everything here is the accent (in different strengths), a neutral, or one
/// of the two status colours, so the app keeps a single look. Each has a light
/// and a dark value; read them via `context.semantics`.
@immutable
class AppSemantics extends ThemeExtension<AppSemantics> {
  const AppSemantics({
    required this.success,
    required this.warning,
    required this.danger,
    required this.streakGold,
    required this.streakHot,
    required this.streakWarm,
    required this.streakCold,
    required this.chartSeries,
    required this.chartGrid,
  });

  final Color success;

  /// A caution that is not an error: the accent itself.
  final Color warning;
  final Color danger;

  /// Streak flame tiers, mirroring the tiers the Android widget renders: the
  /// accent gets stronger as the streak grows, grey when there is none.
  final Color streakGold;
  final Color streakHot;
  final Color streakWarm;
  final Color streakCold;

  final List<Color> chartSeries;
  final Color chartGrid;

  static const light = AppSemantics(
    success: Palette.green600,
    warning: Palette.orange700,
    danger: Palette.red600,
    streakGold: Palette.orange700,
    streakHot: Palette.orange700,
    streakWarm: Palette.orange400,
    streakCold: Palette.stone400,
    chartSeries: [
      Palette.orange700,
      Palette.stone600,
      Palette.orange400,
      Palette.stone400,
    ],
    chartGrid: Palette.stone200,
  );

  static const dark = AppSemantics(
    success: Palette.green400,
    warning: Palette.orange400,
    danger: Palette.red400,
    streakGold: Palette.orange400,
    streakHot: Palette.orange400,
    streakWarm: Palette.orange700,
    streakCold: Palette.stone500,
    chartSeries: [
      Palette.orange400,
      Palette.stone300,
      Palette.orange700,
      Palette.stone500,
    ],
    chartGrid: Palette.nightLine,
  );

  @override
  AppSemantics copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? streakGold,
    Color? streakHot,
    Color? streakWarm,
    Color? streakCold,
    List<Color>? chartSeries,
    Color? chartGrid,
  }) {
    return AppSemantics(
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      streakGold: streakGold ?? this.streakGold,
      streakHot: streakHot ?? this.streakHot,
      streakWarm: streakWarm ?? this.streakWarm,
      streakCold: streakCold ?? this.streakCold,
      chartSeries: chartSeries ?? this.chartSeries,
      chartGrid: chartGrid ?? this.chartGrid,
    );
  }

  @override
  AppSemantics lerp(ThemeExtension<AppSemantics>? other, double t) {
    if (other is! AppSemantics) return this;
    return AppSemantics(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      streakGold: Color.lerp(streakGold, other.streakGold, t)!,
      streakHot: Color.lerp(streakHot, other.streakHot, t)!,
      streakWarm: Color.lerp(streakWarm, other.streakWarm, t)!,
      streakCold: Color.lerp(streakCold, other.streakCold, t)!,
      chartSeries: t < 0.5 ? chartSeries : other.chartSeries,
      chartGrid: Color.lerp(chartGrid, other.chartGrid, t)!,
    );
  }

  /// Flame color for a streak length — keep in sync with the tiers in
  /// `AlarmWidgetProvider.kt`.
  Color streakTier(int days) {
    if (days >= 30) return streakGold;
    if (days >= 7) return streakHot;
    if (days >= 3) return streakWarm;
    return streakCold;
  }
}

extension AppSemanticsX on BuildContext {
  /// Semantic colors for the current brightness.
  AppSemantics get semantics => Theme.of(this).extension<AppSemantics>()!;

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get texts => Theme.of(this).textTheme;
}
