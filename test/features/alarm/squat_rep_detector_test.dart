import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/challenges/squat_rep_detector.dart';

/// Drives the detector with a magnitude held for a span of simulated time.
/// Samples are fed at ~50Hz, like the real accelerometer stream.
DateTime _hold(
  SquatRepDetector detector,
  double magnitude,
  Duration duration,
  DateTime start, {
  void Function()? onRep,
}) {
  var now = start;
  final end = start.add(duration);
  while (now.isBefore(end)) {
    if (detector.addSample(magnitude, now)) onRep?.call();
    now = now.add(const Duration(milliseconds: 20));
  }
  return now;
}

void main() {
  const gravity = 9.8;

  group('SquatRepDetector', () {
    test('calibrates before counting anything', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);

      expect(d.isCalibrating, isTrue);

      // Fewer samples than calibrationSamples: still learning.
      now = _hold(d, gravity, const Duration(milliseconds: 200), now);
      expect(d.isCalibrating, isTrue);

      now = _hold(d, gravity, const Duration(milliseconds: 600), now);
      expect(d.isCalibrating, isFalse);
      expect(d.reps, 0);
    });

    test('counts a full down-and-up as one rep', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);

      now = _hold(d, gravity, const Duration(seconds: 1), now);
      now = _hold(d, gravity - 5, const Duration(milliseconds: 600), now);
      now = _hold(d, gravity + 5, const Duration(milliseconds: 600), now);

      expect(d.reps, 1);
    });

    test('counts several reps in sequence', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);
      now = _hold(d, gravity, const Duration(seconds: 1), now);

      for (var i = 0; i < 5; i++) {
        now = _hold(d, gravity - 5, const Duration(milliseconds: 500), now);
        now = _hold(d, gravity + 5, const Duration(milliseconds: 500), now);
      }

      expect(d.reps, 5);
    });

    test('does not count while simply standing still', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);
      now = _hold(d, gravity, const Duration(seconds: 10), now);

      expect(d.reps, 0);
    });

    test('rapid jitter does not ratchet up the count', () {
      // The whole point of minPhaseMs: shaking the phone must not pass a
      // challenge that is supposed to make you stand up.
      final d = SquatRepDetector();
      var now = DateTime(2026);
      now = _hold(d, gravity, const Duration(seconds: 1), now);

      for (var i = 0; i < 200; i++) {
        d.addSample(i.isEven ? gravity - 8 : gravity + 8, now);
        now = now.add(const Duration(milliseconds: 10));
      }

      // Smoothing plus the phase minimum should keep this far below the
      // number of direction changes (200).
      expect(d.reps, lessThan(10));
    });

    test('a shallow dip below the threshold is ignored', () {
      final d = SquatRepDetector(threshold: 2.5);
      var now = DateTime(2026);
      now = _hold(d, gravity, const Duration(seconds: 1), now);

      now = _hold(d, gravity - 1, const Duration(milliseconds: 600), now);
      now = _hold(d, gravity + 1, const Duration(milliseconds: 600), now);

      expect(d.reps, 0);
    });

    test('adapts its baseline to a device that rests off gravity', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);

      // Some devices report a consistently offset magnitude.
      now = _hold(d, 11.5, const Duration(seconds: 1), now);
      now = _hold(d, 11.5 - 5, const Duration(milliseconds: 600), now);
      now = _hold(d, 11.5 + 5, const Duration(milliseconds: 600), now);

      expect(d.reps, 1);
    });

    test('reset clears both the count and the calibration', () {
      final d = SquatRepDetector();
      var now = DateTime(2026);
      now = _hold(d, gravity, const Duration(seconds: 1), now);
      now = _hold(d, gravity - 5, const Duration(milliseconds: 600), now);
      now = _hold(d, gravity + 5, const Duration(milliseconds: 600), now);
      expect(d.reps, 1);

      d.reset();

      expect(d.reps, 0);
      expect(d.isCalibrating, isTrue);
    });
  });
}
