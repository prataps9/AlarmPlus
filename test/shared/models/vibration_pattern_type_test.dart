import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/shared/models/vibration_pattern_type.dart';

void main() {
  group('VibrationPatternType', () {
    test('off has an empty pattern (no vibration)', () {
      expect(VibrationPatternType.off.pattern, isEmpty);
    });

    test('every non-off pattern is non-empty and has an even length', () {
      // Vibration.vibrate expects alternating [off, on, off, on, ...] pairs;
      // an odd-length pattern silently drops the trailing entry on some
      // platforms, so this is worth guarding.
      for (final type in VibrationPatternType.values) {
        if (type == VibrationPatternType.off) continue;
        expect(type.pattern, isNotEmpty, reason: '$type should vibrate');
        expect(type.pattern.length.isEven, isTrue,
            reason: '$type pattern should have matched on/off pairs');
      }
    });

    test('urgent pulses faster than gentle', () {
      final urgentAvg = _average(VibrationPatternType.urgent.pattern);
      final gentleAvg = _average(VibrationPatternType.gentle.pattern);
      expect(urgentAvg, lessThan(gentleAvg));
    });

    test('every value has a distinct, non-empty label', () {
      final labels = VibrationPatternType.values.map((v) => v.label).toSet();
      expect(labels.length, VibrationPatternType.values.length);
      for (final label in labels) {
        expect(label, isNotEmpty);
      }
    });
  });
}

double _average(List<int> values) =>
    values.reduce((a, b) => a + b) / values.length;
