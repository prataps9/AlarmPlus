import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

class StepCounterChallengeWidget extends StatefulWidget {
  const StepCounterChallengeWidget({
    super.key,
    required this.onPassed,
    required this.onFailed,
    this.stepGoal = 20,
  });

  final VoidCallback onPassed;
  final VoidCallback onFailed;
  final int stepGoal;

  @override
  State<StepCounterChallengeWidget> createState() => _StepCounterChallengeWidgetState();
}

class _StepCounterChallengeWidgetState extends State<StepCounterChallengeWidget> {
  StreamSubscription<StepCount>? _subscription;
  int _baseline = -1;
  int _stepsDone = 0;
  bool _permissionDenied = false;
  bool _passed = false;

  @override
  void initState() {
    super.initState();
    _initPedometer();
  }

  Future<void> _initPedometer() async {
    final status = await Permission.activityRecognition.request();
    if (!mounted) return;
    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _permissionDenied = true);
      return;
    }
    _subscription = Pedometer.stepCountStream.listen(
      _onStep,
      onError: (_) {
        if (mounted) setState(() => _permissionDenied = true);
      },
    );
  }

  void _onStep(StepCount event) {
    if (!mounted || _passed) return;
    if (_baseline == -1) {
      _baseline = event.steps;
    }
    final done = event.steps - _baseline;
    setState(() => _stepsDone = done.clamp(0, widget.stepGoal));
    if (done >= widget.stepGoal) {
      _passed = true;
      _subscription?.cancel();
      widget.onPassed();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionDenied) {
      return _buildPermissionDenied();
    }

    final progress = widget.stepGoal > 0 ? _stepsDone / widget.stepGoal : 0.0;
    final remaining = (widget.stepGoal - _stepsDone).clamp(0, widget.stepGoal);
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.directions_walk_rounded, color: Color(0xFF10B981), size: 22),
            const SizedBox(width: 8),
            const Text('Step Counter',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF10B981))),
          ]),
          const SizedBox(height: 24),
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(alignment: Alignment.center, children: [
              // Fill the 160px box: a Stack passes loose constraints, so on
              // its own the indicator shrank to its 36px default.
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: scheme.outlineVariant,
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
                ),
              ),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(
                  '$_stepsDone',
                  style: const TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w900, color: Color(0xFF10B981)),
                ).animate(key: ValueKey(_stepsDone)).scale(
                    begin: const Offset(1.3, 1.3),
                    end: const Offset(1.0, 1.0),
                    duration: 200.ms,
                    curve: Curves.easeOut),
                Text('steps', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ]),
            ]),
          ),
          const SizedBox(height: 20),
          Text(
            remaining > 0
                ? '$remaining more steps to dismiss'
                : 'Done! Dismissing...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: remaining > 0 ? scheme.onSurfaceVariant : const Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Walk around to wake up fully!',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: scheme.outlineVariant,
            valueColor: const AlwaysStoppedAnimation(Color(0xFF10B981)),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
          color: scheme.surfaceContainer, borderRadius: BorderRadius.circular(28)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.directions_walk_rounded, color: scheme.onSurfaceVariant, size: 40),
          const SizedBox(height: 16),
          const Text('Activity Permission Required',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'Enable Activity Recognition in Settings to use the Step Counter challenge.',
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Open Settings'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: widget.onPassed,
            child: Text('Skip for now', style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
