/// Counts squat repetitions from accelerometer magnitude samples.
///
/// Kept free of Flutter and of the sensor plugin so the detection logic can be
/// unit-tested with synthetic samples — the behaviour that matters (not
/// counting a rep for random shaking) is impossible to check by eye.
///
/// How it works: at rest the magnitude sits near gravity (~9.8). Dropping into
/// a squat briefly reduces it; driving back up overshoots above it. So a rep is
/// a dip below `baseline - threshold` followed by a rise above
/// `baseline + threshold`, with each phase having to last [minPhaseMs] so that
/// fast jiggling can't ratchet the count up.
class SquatRepDetector {
  SquatRepDetector({
    this.threshold = 2.5,
    this.minPhaseMs = 250,
    this.calibrationSamples = 30,
    this.smoothing = 0.2,
  });

  /// How far from the resting baseline counts as a real movement, in m/s².
  final double threshold;

  /// Minimum duration of each half of a rep, rejecting shake-spam.
  final int minPhaseMs;

  /// Samples averaged to learn the resting baseline before counting starts.
  final int calibrationSamples;

  /// EMA factor; lower is smoother.
  final double smoothing;

  double? _baseline;
  double _calibrationTotal = 0;
  int _calibrationCount = 0;

  double? _smoothed;
  _Phase _phase = _Phase.upright;
  DateTime? _phaseSince;
  int _reps = 0;

  int get reps => _reps;

  /// True until enough still samples have been seen to know what "at rest"
  /// looks like for this device and pocket.
  bool get isCalibrating => _baseline == null;

  /// True while the user is detected as being down in the squat.
  bool get isDown => _phase == _Phase.down;

  /// Feeds one sample. Returns true if it completed a rep.
  bool addSample(double magnitude, DateTime now) {
    _smoothed = _smoothed == null
        ? magnitude
        : _smoothed! + smoothing * (magnitude - _smoothed!);
    final value = _smoothed!;

    if (_baseline == null) {
      _calibrationTotal += value;
      _calibrationCount++;
      if (_calibrationCount >= calibrationSamples) {
        _baseline = _calibrationTotal / _calibrationCount;
        _phaseSince = now;
      }
      return false;
    }

    final base = _baseline!;
    final heldLongEnough = _phaseSince == null ||
        now.difference(_phaseSince!).inMilliseconds >= minPhaseMs;

    switch (_phase) {
      case _Phase.upright:
        if (value < base - threshold && heldLongEnough) {
          _phase = _Phase.down;
          _phaseSince = now;
        }
      case _Phase.down:
        if (value > base + threshold && heldLongEnough) {
          _phase = _Phase.upright;
          _phaseSince = now;
          _reps++;
          return true;
        }
    }

    return false;
  }

  /// Forgets the learned baseline and the count.
  void reset() {
    _baseline = null;
    _calibrationTotal = 0;
    _calibrationCount = 0;
    _smoothed = null;
    _phase = _Phase.upright;
    _phaseSince = null;
    _reps = 0;
  }
}

enum _Phase { upright, down }
