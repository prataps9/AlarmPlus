import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/missions/models/wake_routine_step.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/sleep/services/wake_routine_service.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';

class WakeRoutineScreen extends StatefulWidget {
  const WakeRoutineScreen({super.key});

  static const routeName = '/wake-routine';

  @override
  State<WakeRoutineScreen> createState() => _WakeRoutineScreenState();
}

class _WakeRoutineScreenState extends State<WakeRoutineScreen>
    with TickerProviderStateMixin {
  final List<WakeRoutineStep> _steps = WakeRoutineService.defaultSteps;

  int _stepIndex = 0;
  int _secondsLeft = 0;
  int _completedCount = 0;
  bool _finishing = false;
  bool _stepDone = false;

  // Breath phase: 0=inhale, 1=hold, 2=exhale
  int _breathPhase = 0;
  int _breathPhaseSeconds = 0;
  static const _breathPhaseDurations = [4, 4, 4];
  static const _breathPhaseLabels = ['Inhale', 'Hold', 'Exhale'];

  late AnimationController _timerController;
  late AnimationController _breathController;
  Timer? _countdownTimer;

  WakeRoutineStep get _currentStep => _steps[_stepIndex];

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(vsync: this);
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _startStep();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    _breathController.dispose();
    super.dispose();
  }

  void _startStep() {
    _countdownTimer?.cancel();
    final step = _currentStep;
    setState(() {
      _secondsLeft = step.durationSeconds;
      _stepDone = false;
      _breathPhase = 0;
      _breathPhaseSeconds = _breathPhaseDurations[0];
    });

    _timerController.duration = Duration(seconds: step.durationSeconds);
    _timerController.forward(from: 0);

    if (step.isTimedBreath) {
      _breathController.repeat(reverse: true);
    } else {
      _breathController.stop();
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _secondsLeft--;
        if (step.isTimedBreath) {
          _breathPhaseSeconds--;
          if (_breathPhaseSeconds <= 0) {
            _breathPhase = (_breathPhase + 1) % 3;
            _breathPhaseSeconds = _breathPhaseDurations[_breathPhase];
          }
        }
        if (_secondsLeft <= 0) {
          t.cancel();
          _stepDone = true;
        }
      });
    });
  }

  void _advance({required bool completed}) {
    // A double tap on the last "Done" ran _finish twice (and paid twice).
    if (_finishing) return;
    _countdownTimer?.cancel();
    if (completed) {
      _completedCount++;
    }

    if (_stepIndex < _steps.length - 1) {
      setState(() => _stepIndex++);
      _startStep();
    } else {
      _finishing = true;
      _finish();
    }
  }

  Future<void> _finish() async {
    var bonus = WakeRoutineService.calculateAwakeBonus(
      _completedCount,
      _steps.length,
    );
    await WakeRoutineService.markRoutineCompleted();
    // Paid once a day; replaying the routine doesn't pay again.
    if (bonus > 0 && !await SmartAlarmService.claimDailyXp('wake_routine')) {
      bonus = 0;
    }
    if (bonus > 0) {
      await SmartAlarmService.addXp(bonus);
    }
    if (!mounted) return;
    _showCompletionSheet(bonus);
  }

  void _showCompletionSheet(int bonus) {
    showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🌟', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            const Text(
              'Wake Routine Complete!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              '$_completedCount / ${_steps.length} steps'
              '${bonus > 0 ? ' · +$bonus XP' : ''}',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushReplacementNamed(
                    MorningMissionsScreen.routeName,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: const Text(
                  'Start Morning Missions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pushNamed('/morning-checkin');
              },
              child: const Text(
                'Sleep Check-In',
                style: TextStyle(color: Color(0xFF6366F1)),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop();
              },
              child: Text(
                'Skip missions',
                style: TextStyle(
                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_stepIndex) / _steps.length;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'WAKE ROUTINE',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            color: scheme.onSurfaceVariant,
          ),
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: scheme.outlineVariant,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF22C55E),
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Step ${_stepIndex + 1} of ${_steps.length}',
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            // Step icon
            Center(
              child: Text(
                _currentStep.icon,
                style: const TextStyle(fontSize: 72),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Center(
              child: Text(
                _currentStep.title,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            // Instruction
            Center(
              child: Text(
                _currentStep.instruction,
                style: TextStyle(
                  fontSize: 16,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 36),
            // Timer ring or breath indicator
            Center(
              child: _currentStep.isTimedBreath
                  ? _buildBreathIndicator()
                  : _buildTimerRing(),
            ),
            const Spacer(),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _advance(completed: false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 52),
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _stepDone ? () => _advance(completed: true) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                    child: Text(
                      _stepIndex < _steps.length - 1 ? 'Done  →' : 'Finish',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerRing() {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _timerController,
            builder: (context, child) => CustomPaint(
              size: const Size(140, 140),
              painter: _RingPainter(
                progress: 1.0 - _timerController.value,
                color: const Color(0xFF22C55E),
                trackColor: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          Text(
            '$_secondsLeft',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreathIndicator() {
    final label = _breathPhaseLabels[_breathPhase];
    return Column(
      children: [
        AnimatedBuilder(
          animation: _breathController,
          builder: (context, child) {
            final scale = 0.7 + (_breathController.value * 0.3);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                  border: Border.all(
                    color: const Color(0xFF22C55E),
                    width: 3,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        Text(
          '$_breathPhaseSeconds s',
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.trackColor != trackColor;
}
