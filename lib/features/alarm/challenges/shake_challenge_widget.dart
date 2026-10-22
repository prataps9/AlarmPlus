import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class ShakeChallengeWidget extends StatefulWidget {
  const ShakeChallengeWidget({
    super.key,
    required this.onPassed,
    this.onFailed,
  });

  final VoidCallback onPassed;
  final VoidCallback? onFailed;
  static const _requiredShakes = 20;
  static const _timeoutSeconds = 60;

  @override
  State<ShakeChallengeWidget> createState() => _ShakeChallengeWidgetState();
}

class _ShakeChallengeWidgetState extends State<ShakeChallengeWidget> {
  int _shakeCount = 0;
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _timeoutTimer;
  int _secondsLeft = ShakeChallengeWidget._timeoutSeconds;
  double _prevMag = 0;
  bool _noSensor = false;
  static const _threshold = 15.0;

  static bool get _hasAccelerometer =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_hasAccelerometer) {
      // Desktop / web: no hardware sensor — auto-pass after brief delay
      setState(() => _noSensor = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onPassed();
      });
      return;
    }

    try {
      _sub = accelerometerEventStream().listen(
        (event) {
          final mag = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
          if (_prevMag > 0 && (mag - _prevMag).abs() > _threshold) {
            setState(() => _shakeCount++);
            if (_shakeCount >= ShakeChallengeWidget._requiredShakes) {
              _complete();
            }
          }
          _prevMag = mag;
        },
        onError: (_) {
          if (mounted) setState(() => _noSensor = true);
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) widget.onPassed();
          });
        },
      );
    } catch (_) {
      setState(() => _noSensor = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) widget.onPassed();
      });
      return;
    }

    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) {
        t.cancel();
        _sub?.cancel();
        widget.onFailed?.call();
      }
    });
  }

  void _complete() {
    _timeoutTimer?.cancel();
    _sub?.cancel();
    widget.onPassed();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cardBg = scheme.surfaceContainer;

    if (_noSensor) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('📳', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text('No sensor detected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 6),
            Text('Auto-passing…', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    final progress = _shakeCount / ShakeChallengeWidget._requiredShakes;
    final timerFraction = _secondsLeft / ShakeChallengeWidget._timeoutSeconds;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: timerFraction,
                      strokeWidth: 3,
                      backgroundColor: scheme.outlineVariant,
                      valueColor: AlwaysStoppedAnimation(
                        timerFraction > 0.4 ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
                      ),
                    ),
                    Text('$_secondsLeft',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ],
          ),
          const Text('📳', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          const Text(
            'Shake your phone!',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22),
          ),
          const SizedBox(height: 8),
          Text(
            '$_shakeCount / ${ShakeChallengeWidget._requiredShakes} shakes',
            style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: scheme.outlineVariant,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22C55E)),
            ),
          ),
        ],
      ),
    );
  }
}
