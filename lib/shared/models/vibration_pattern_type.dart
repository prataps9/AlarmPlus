/// A per-alarm vibration intensity. Replaces the hardcoded `[500, 1000]`
/// pattern every alarm used to ring with regardless of its own settings.
enum VibrationPatternType { gentle, standard, urgent, off }

extension VibrationPatternTypeX on VibrationPatternType {
  /// Millisecond on/off pairs passed to `Vibration.vibrate(pattern: ...)`.
  /// Empty means "don't vibrate at all" (distinct from the global vibration
  /// toggle being off — this is a per-alarm choice).
  List<int> get pattern {
    switch (this) {
      case VibrationPatternType.gentle:
        return const [300, 800, 300, 1200];
      case VibrationPatternType.standard:
        return const [500, 1000];
      case VibrationPatternType.urgent:
        return const [200, 300, 200, 300, 200, 300];
      case VibrationPatternType.off:
        return const [];
    }
  }

  String get label {
    switch (this) {
      case VibrationPatternType.gentle:
        return 'Gentle';
      case VibrationPatternType.standard:
        return 'Standard';
      case VibrationPatternType.urgent:
        return 'Urgent';
      case VibrationPatternType.off:
        return 'Off';
    }
  }
}
