import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// A wake-up light: the screen warms from midnight purple to daylight over
/// the ramp, and — when [rampBrightness] is set — the device's own screen
/// brightness climbs with it, which is what makes this actually work as a
/// light rather than just a pretty background.
///
/// The brightness change is scoped to this app and reset on dispose, so
/// leaving the ring screen restores whatever the user had.
class SunriseGradient extends StatefulWidget {
  const SunriseGradient({
    super.key,
    required this.durationSeconds,
    required this.child,
    this.rampBrightness = false,
  });

  final int durationSeconds;
  final Widget child;

  /// Raise the device's screen brightness alongside the colour ramp.
  final bool rampBrightness;

  @override
  State<SunriseGradient> createState() => _SunriseGradientState();
}

class _SunriseGradientState extends State<SunriseGradient>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _stops = [
    Color(0xFF1a0533), // midnight purple
    Color(0xFF7c3aed), // deep violet
    Color(0xFFf97316), // deep orange
    Color(0xFFfbbf24), // golden
    Color(0xFFfef9c3), // soft white-yellow
  ];

  /// Starting point of the brightness ramp. Not 0: a screen at true zero
  /// reads as broken rather than as a sunrise about to begin.
  static const _minBrightness = 0.05;

  bool _brightnessTouched = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );

    if (widget.rampBrightness) {
      _controller.addListener(_applyBrightness);
    }
    _controller.forward();
  }

  void _applyBrightness() {
    final target = _minBrightness + _controller.value * (1 - _minBrightness);
    _brightnessTouched = true;
    // Fire-and-forget: a dropped frame of brightness is not worth awaiting,
    // and the plugin is absent on some platforms.
    ScreenBrightness.instance
        .setApplicationScreenBrightness(target.clamp(0.0, 1.0))
        .catchError((Object e) => debugPrint('sunrise brightness failed: $e'));
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_brightnessTouched) {
      // Hand the screen back to whatever the user had set.
      ScreenBrightness.instance.resetApplicationScreenBrightness().catchError(
            (Object e) => debugPrint('sunrise brightness reset failed: $e'),
          );
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        final colorIndex = (t * (_stops.length - 1)).floor().clamp(0, _stops.length - 2);
        final localT = (t * (_stops.length - 1)) - colorIndex;
        final color = Color.lerp(_stops[colorIndex], _stops[colorIndex + 1], localT)!;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [color, color.withValues(alpha: 0.6)],
            ),
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
