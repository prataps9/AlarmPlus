import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/features/alarm/challenges/barcode_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/color_clash_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/eye_open_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/memory_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/shake_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/squat_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/step_counter_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/voice_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/trivia_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/typing_challenge_widget.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/shared/models/quest_model.dart';
import 'package:alarm_plus/features/alarm/services/challenge_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/widgets/math_challenge_widget.dart';

class QuestRunnerWidget extends StatefulWidget {
  const QuestRunnerWidget({
    super.key,
    required this.quest,
    required this.stepGoal,
    required this.squatReps,
    required this.lockedQrCode,
    required this.onCompleted,
    required this.onFailed,
  });

  final WakeQuest quest;
  final int stepGoal;
  final int squatReps;
  final String? lockedQrCode;
  final VoidCallback onCompleted;
  final VoidCallback onFailed;

  @override
  State<QuestRunnerWidget> createState() => _QuestRunnerWidgetState();
}

class _QuestRunnerWidgetState extends State<QuestRunnerWidget> {
  int _currentStep = 0;
  late List<bool> _completed;

  @override
  void initState() {
    super.initState();
    _completed = List.filled(widget.quest.steps.length, false);
  }

  void _onStepPassed() {
    setState(() {
      _completed[_currentStep] = true;
    });
    if (_currentStep + 1 >= widget.quest.steps.length) {
      Future.delayed(const Duration(milliseconds: 600), widget.onCompleted);
    } else {
      Future.delayed(const Duration(milliseconds: 400), () {
        if (mounted) setState(() => _currentStep++);
      });
    }
  }

  void _onStepFailed() {
    // On fail, don't advance — re-show the same challenge
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.quest.steps.length;
    final step = widget.quest.steps[_currentStep];

    final cardBg = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(children: [
              Row(children: [
                const Icon(Icons.rocket_launch_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 8),
                const Text('Wake Quest',
                    style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF6366F1))),
                const Spacer(),
                Text('${_currentStep + 1} / $total',
                    style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              _QuestStepBar(
                steps: widget.quest.steps,
                currentStep: _currentStep,
                completed: _completed,
              ),
              const SizedBox(height: 16),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) =>
                  FadeTransition(opacity: anim, child: child),
              child: KeyedSubtree(
                key: ValueKey(_currentStep),
                child: _buildCurrentChallenge(step.challengeType),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentChallenge(ChallengeType type) {
    switch (type) {
      case ChallengeType.math:
        return MathChallengeWidget(
          difficulty: MathDifficulty.medium,
          isBossMode: false,
          onCompleted: (_, __, ___) => _onStepPassed(),
          onFailed: _onStepFailed,
        );
      case ChallengeType.memoryPattern:
        return MemoryChallengeWidget(
            onPassed: _onStepPassed, onFailed: _onStepFailed);
      case ChallengeType.shakeToWake:
        return ShakeChallengeWidget(onPassed: _onStepPassed, onFailed: _onStepFailed);
      case ChallengeType.typing:
        return TypingChallengeWidget(
            onPassed: _onStepPassed, onFailed: _onStepFailed);
      case ChallengeType.barcodeScan:
        return SizedBox(
          height: 300,
          child: BarcodeChallengeWidget(
            lockedQrCode: widget.lockedQrCode,
            onPassed: _onStepPassed,
            onFailed: _onStepFailed,
          ),
        );
      case ChallengeType.trivia:
        return TriviaChallengeWidget(
            onPassed: _onStepPassed, onFailed: _onStepFailed);
      case ChallengeType.wordScramble:
        return TriviaChallengeWidget(
          mode: TriviaMode.wordScramble,
          onPassed: _onStepPassed,
          onFailed: _onStepFailed,
        );
      case ChallengeType.stepCounter:
        return StepCounterChallengeWidget(
          stepGoal: widget.stepGoal,
          onPassed: _onStepPassed,
          onFailed: _onStepFailed,
        );
      case ChallengeType.eyeOpen:
        return SizedBox(
          height: 320,
          child: EyeOpenChallengeWidget(
            onPassed: _onStepPassed,
            onFailed: _onStepFailed,
          ),
        );
      case ChallengeType.squatReps:
        return SquatChallengeWidget(
          targetReps: widget.squatReps,
          onPassed: _onStepPassed,
          onFailed: _onStepFailed,
        );
      case ChallengeType.voiceRepeat:
        return VoiceChallengeWidget(
          onPassed: _onStepPassed,
          onFailed: _onStepFailed,
        );
      case ChallengeType.colorClash:
        return ColorClashChallengeWidget(
          onPassed: _onStepPassed,
          onFailed: _onStepFailed,
        );
      case ChallengeType.photoProof:
        // Photo proof needs a registered scene, which quest steps don't carry;
        // it isn't offered in the builder, but the switch must be total.
        return MathChallengeWidget(
          difficulty: MathDifficulty.medium,
          isBossMode: false,
          onCompleted: (_, __, ___) => _onStepPassed(),
          onFailed: _onStepFailed,
        );
      case ChallengeType.random:
        return _buildCurrentChallenge(ChallengeService.randomChallenge());
    }
  }
}

class _QuestStepBar extends StatelessWidget {
  const _QuestStepBar({
    required this.steps,
    required this.currentStep,
    required this.completed,
  });

  final List<QuestStep> steps;
  final int currentStep;
  final List<bool> completed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(steps.length, (i) {
        final isActive = i == currentStep;
        final isDone = completed[i];
        Color bg;
        Color border;
        Widget icon;

        if (isDone) {
          bg = const Color(0xFF22C55E);
          border = const Color(0xFF22C55E);
          icon = const Icon(Icons.check_rounded, color: Colors.white, size: 16);
        } else if (isActive) {
          bg = const Color(0xFF6366F1);
          border = const Color(0xFF6366F1);
          icon = Icon(_iconFor(steps[i].challengeType),
              color: Colors.white, size: 16);
        } else {
          bg = const Color(0xFFF8FAFC);
          border = const Color(0xFFE2E8F0);
          icon = Icon(_iconFor(steps[i].challengeType),
              color: const Color(0xFFCBD5E1), size: 16);
        }

        return Expanded(
          child: Row(children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border, width: 1.5),
                ),
                child: Center(child: icon),
              ).animate(target: isActive ? 1 : 0).scale(
                  begin: const Offset(0.95, 0.95),
                  end: const Offset(1.0, 1.0),
                  duration: 200.ms),
            ),
            if (i < steps.length - 1)
              Container(
                width: 6,
                height: 2,
                color: isDone
                    ? const Color(0xFF22C55E)
                    : const Color(0xFFE2E8F0),
              ),
          ]),
        );
      }),
    );
  }

  IconData _iconFor(ChallengeType type) {
    switch (type) {
      case ChallengeType.math:
        return Icons.calculate_rounded;
      case ChallengeType.memoryPattern:
        return Icons.grid_view_rounded;
      case ChallengeType.shakeToWake:
        return Icons.vibration_rounded;
      case ChallengeType.typing:
        return Icons.keyboard_rounded;
      case ChallengeType.barcodeScan:
        return Icons.qr_code_rounded;
      case ChallengeType.trivia:
        return Icons.quiz_rounded;
      case ChallengeType.wordScramble:
        return Icons.text_fields_rounded;
      case ChallengeType.stepCounter:
        return Icons.directions_walk_rounded;
      case ChallengeType.eyeOpen:
        return Icons.remove_red_eye_rounded;
      case ChallengeType.squatReps:
        return Icons.fitness_center_rounded;
      case ChallengeType.photoProof:
        return Icons.photo_camera_rounded;
      case ChallengeType.voiceRepeat:
        return Icons.record_voice_over_rounded;
      case ChallengeType.colorClash:
        return Icons.palette_rounded;
      case ChallengeType.random:
        return Icons.shuffle_rounded;
    }
  }
}
