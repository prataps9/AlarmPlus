/// "Flip to snooze": decides from accelerometer readings when the phone has
/// been laid face down. Pure (time and readings are passed in) so it is
/// testable; the ring screen feeds it `sensors_plus` events.
class FlipDetector {
  FlipDetector({
    this.hold = const Duration(milliseconds: 900),
    this.threshold = -8.0,
  });

  /// How long the phone must stay face down. Brief tilts (picking it up,
  /// rolling over in bed) don't count.
  final Duration hold;

  /// Z acceleration (m/s²) below which the screen faces the floor; gravity
  /// is about -9.8 when perfectly flat.
  final double threshold;

  DateTime? _downSince;
  bool _fired = false;

  /// Feeds one reading; returns true exactly once, when the phone has been
  /// face down for [hold]. Turning it face up again re-arms it.
  bool add(double z, DateTime at) {
    if (z > threshold) {
      _downSince = null;
      _fired = false;
      return false;
    }
    _downSince ??= at;
    if (_fired || at.difference(_downSince!) < hold) return false;
    _fired = true;
    return true;
  }
}
