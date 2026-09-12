import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/challenges/squat_rep_detector.dart';

/// Dismiss by physically standing up and squatting — hard to fake half-asleep.
class SquatChallengeWidget extends StatefulWidget {
  const SquatChallengeWidget({
    super.key,
    required this.onPassed,
    this.onFailed,
    this.targetReps = 10,
  });

  final VoidCallback onPassed;
  final VoidCallback? onFailed;
  final int targetReps;

  static const timeoutSeconds = 90;

  @override
  State<SquatChallengeWidget> createState() => _SquatChallengeWidgetState();
}

class _SquatChallengeWidgetState extends State<SquatChallengeWidget> {
  final _detector = SquatRepDetector();
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _timer;
  int _secondsLeft = SquatChallengeWidget.timeoutSeconds;
  bool _noSensor = false;

  static bool get _hasAccelerometer =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    if (!_hasAccelerometer) {
      _fallbackToAutoPass();
      return;
    }

    try {
      _sub = accelerometerEventStream().listen(
        _onSample,
        onError: (_) => _fallbackToAutoPass(),
      );
    } catch (_) {
      _fallbackToAutoPass();
      return;
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
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

  void _onSample(AccelerometerEvent event) {
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );
    final completedRep = _detector.addSample(magnitude, DateTime.now());
    if (!mounted) return;

    setState(() {});
    if (completedRep && _detector.reps >= widget.targetReps) {
      _timer?.cancel();
      _sub?.cancel();
      widget.onPassed();
    }
  }

  /// No usable sensor (desktop, web, or a device that errors) — don't trap the
  /// user behind a challenge their hardware can't satisfy.
  void _fallbackToAutoPass() {
    if (!mounted) return;
    setState(() => _noSensor = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) widget.onPassed();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_noSensor) {
      return _Shell(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🏋️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: Spacing.md),
            Text('No motion sensor', style: theme.textTheme.titleLarge),
            const SizedBox(height: Spacing.xs),
            Text('Auto-passing…', style: theme.textTheme.bodyMedium),
          ],
        ),
      );
    }

    final reps = _detector.reps;
    final progress = (reps / widget.targetReps).clamp(0.0, 1.0);
    final timerFraction = _secondsLeft / SquatChallengeWidget.timeoutSeconds;

    final hint = _detector.isCalibrating
        ? 'Stand still for a moment…'
        : _detector.isDown
            ? 'Now stand up'
            : 'Squat down';

    return _Shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: timerFraction,
                    strokeWidth: 3,
                    backgroundColor: theme.colorScheme.outlineVariant,
                  ),
                  Text('$_secondsLeft', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const Text('🏋️', style: TextStyle(fontSize: 56)),
          const SizedBox(height: Spacing.md),
          Text('Do $_repsLabel', style: theme.textTheme.headlineSmall),
          const SizedBox(height: Spacing.sm),
          Text(hint, style: theme.textTheme.bodyMedium),
          const SizedBox(height: Spacing.xl),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.sm),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: theme.colorScheme.outlineVariant,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            '$reps / ${widget.targetReps}',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }

  String get _repsLabel =>
      widget.targetReps == 1 ? '1 squat' : '${widget.targetReps} squats';
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Spacing.xxl),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      child: child,
    );
  }
}
