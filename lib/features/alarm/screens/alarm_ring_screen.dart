import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:volume_controller/volume_controller.dart';

import 'package:alarm_plus/features/alarm/challenges/photo_hash.dart';
import 'package:alarm_plus/features/alarm/challenges/photo_proof_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/squat_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/voice_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/barcode_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/eye_open_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/memory_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/shake_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/step_counter_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/trivia_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/typing_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/models/alarm_personality.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/features/alarm/models/alarm_ring_event.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/alarm/services/challenge_service.dart';
import 'package:alarm_plus/features/sleep/services/sleep_analytics_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/sleep/services/voice_memo_service.dart';
import 'package:alarm_plus/shared/models/quest_model.dart';
import 'package:alarm_plus/features/alarm/widgets/math_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/widgets/quest_runner_widget.dart';
import 'package:alarm_plus/shared/widgets/sunrise_gradient.dart';
import 'package:alarm_plus/features/sleep/screens/wake_routine_screen.dart';
import 'package:alarm_plus/core/services/celebration_event.dart';
import 'package:alarm_plus/core/services/share_service.dart';
import 'package:alarm_plus/shared/widgets/share_card_widget.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key});
  static const routeName = '/alarm-ring';

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  MathDifficulty _mathDifficulty = MathDifficulty.easy;
  bool _mathChallengeEnabled = true;
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  double _dragDx = 0.0;
  bool _isDismissing = false;
  PersonalityConfig _personality = PersonalityConfig.all[AlarmPersonality.gentle]!;
  int _wrongAnswers = 0;
  int _quickSolveXp = 0;
  final int _dismissStartMs = DateTime.now().millisecondsSinceEpoch;

  // Gentle wake volume ramp
  int _gentleSecondsLeft = 0;
  bool _gentleWakeActive = false;

  int get _alarmId {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return (args['alarmId'] as int?) ?? 0;
    if (args is int) return args;
    return 0;
  }

  int get _snoozeCount {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) return (args['snoozeCount'] as int?) ?? 0;
    return 0;
  }

  bool get _isBossMode => _snoozeCount >= 2;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
    _ringController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final diff = await SmartAlarmService.getMathDifficulty();
    final challengeType = await SmartAlarmService.getDismissChallenge();
    if (!mounted) return;
    setState(() {
      _mathDifficulty = _isBossMode ? MathDifficulty.boss : diff;
      _mathChallengeEnabled = challengeType != DismissChallengeType.none;
    });
    final alarmId = _alarmId;
    if (alarmId > 0) {
      final alarm = AlarmService.findByIntId(alarmId);
      if (alarm != null && mounted) {
        final config = PersonalityConfig.forName(alarm.personality);
        setState(() => _personality = config);
        await SmartAlarmService.recordPersonalityUsed(alarm.personality);
        if (alarm.gentleWake) {
          _startGentleWake(alarm);
        } else {
          VolumeController.instance.setVolume(alarm.alarmVolume);
        }
      }
      // Guardian timer is owned by AlarmRingFlow — no duplicate needed here.
    }
  }

  void _startGentleWake(AlarmModel alarm) {
    setState(() {
      _gentleSecondsLeft = alarm.gentleWakeDurationSeconds;
      _gentleWakeActive = true;
    });
    final ceiling = alarm.alarmVolume;
    VolumeController.instance.setVolume(0.1);

    final duration = alarm.gentleWakeDurationSeconds;
    final stepCount = duration;

    var elapsed = 0;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_gentleWakeActive) return false;
      elapsed++;
      final vol = 0.1 + (elapsed / stepCount) * (ceiling - 0.1);
      VolumeController.instance.setVolume(vol.clamp(0.1, ceiling));
      if (mounted) setState(() => _gentleSecondsLeft = duration - elapsed);
      return elapsed < stepCount && _gentleWakeActive;
    });
  }

  void _stopGentleWake() {
    if (_gentleWakeActive) {
      _gentleWakeActive = false;
      VolumeController.instance.setVolume(1.0);
    }
  }

  @override
  void dispose() {
    _gentleWakeActive = false;
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  Future<void> _triggerDismiss(int alarmId) async {
    if (_isDismissing) return;
    // Muted for the whole dismiss→celebration-sheet sequence so the global
    // celebration banner (level-up/badge) doesn't pop up behind or before
    // this screen's own detailed sheet. Confetti still fires either way.
    CelebrationBus.mutePresentation = true;
    try {
      final alarm = AlarmService.findByIntId(alarmId);

      // Always require a challenge: use alarm's configured type, fall back to math
      final alarmHasChallenge = alarm != null &&
          (alarm.questMode || alarm.challengeType != null);
      final shouldChallenge = alarmHasChallenge || _mathChallengeEnabled;

      if (shouldChallenge) {
        bool passed;

        if (alarm != null && alarm.questMode) {
          passed = await _showQuestChallenge(alarm);
        } else {
          final resolvedChallenge = alarm != null
              ? ChallengeService.pickChallenge(alarm)
              : ChallengeType.math;
          passed = await _showChallenge(resolvedChallenge);
        }

        if (!passed) {
          setState(() => _dragDx = 0.0);
          return;
        }
      }

      // Auto-play voice memo if present and file still exists
      final memoPath = alarm?.voiceMemoPath;
      if (memoPath != null && await File(memoPath).exists()) {
        try {
          await VoiceMemoService.playMemo(memoPath);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        } catch (e) {
          debugPrint('Voice memo playback failed: $e');
        }
      }

      _stopGentleWake();
      setState(() => _isDismissing = true);
      final reward = await AlarmRingFlow.stopAlarm(alarmId);
      if (!mounted) return;
      final dismissMs = DateTime.now().millisecondsSinceEpoch - _dismissStartMs;
      final mood = await SmartAlarmService.getLatestMoodCheckIn();
      final now = DateTime.now();
      final moodToday = mood != null &&
          mood.at.year == now.year &&
          mood.at.month == now.month &&
          mood.at.day == now.day;
      final wakeScore = SmartAlarmService.calculateWakeScore(
        dismissSpeedSeconds: dismissMs ~/ 1000,
        wrongAnswers: _wrongAnswers,
        snoozeCount: _snoozeCount,
        moodCheckInDoneToday: moodToday,
      );
      final prevBest = await SmartAlarmService.saveWakeScore(wakeScore);

      // Record sleep analytics event
      final scheduledToday = alarm != null
          ? DateTime(now.year, now.month, now.day, alarm.time.hour, alarm.time.minute)
          : now;
      await SleepAnalyticsService.recordEvent(AlarmRingEvent(
        alarmId: alarm?.id ?? '',
        scheduledTime: scheduledToday,
        actualDismissTime: now,
        snoozeCount: _snoozeCount,
        wasMissed: false,
        wakeScore: wakeScore.total,
      ));

      if (!mounted) return;
      await _showCelebrationSheet(reward, wakeScore, prevBest);
      AlarmRingFlow.completeRingScreenDismiss();
      if (mounted) {
        Navigator.of(context).pushNamed(WakeRoutineScreen.routeName);
      }
    } finally {
      CelebrationBus.mutePresentation = false;
    }
  }

  Future<bool> _showChallenge(ChallengeType type) async {
    switch (type) {
      case ChallengeType.math:
        return _showMathChallenge();
      case ChallengeType.memoryPattern:
        return _showOverlayChallenge((onPass, onFail) => MemoryChallengeWidget(onPassed: onPass, onFailed: onFail));
      case ChallengeType.shakeToWake:
        return _showShakeChallenge();
      case ChallengeType.typing:
        return _showOverlayChallenge((onPass, onFail) => TypingChallengeWidget(onPassed: onPass, onFailed: onFail));
      case ChallengeType.barcodeScan:
        return _showBarcodeChallenge();
      case ChallengeType.trivia:
        return _showOverlayChallenge(
          (onPass, onFail) => TriviaChallengeWidget(onPassed: onPass, onFailed: onFail),
        );
      case ChallengeType.wordScramble:
        return _showOverlayChallenge(
          (onPass, onFail) => TriviaChallengeWidget(
            onPassed: onPass,
            onFailed: onFail,
            mode: TriviaMode.wordScramble,
          ),
        );
      case ChallengeType.stepCounter:
        return _showStepCounterChallenge();
      case ChallengeType.eyeOpen:
        return _showEyeOpenChallenge();
      case ChallengeType.squatReps:
        return _showOverlayChallenge(
          (onPass, onFail) => SquatChallengeWidget(
            onPassed: onPass,
            onFailed: onFail,
            targetReps: AlarmService.findByIntId(_alarmId)?.squatReps ?? 10,
          ),
        );
      case ChallengeType.photoProof:
        return _showPhotoProofChallenge();
      case ChallengeType.voiceRepeat:
        return _showOverlayChallenge(
          (onPass, onFail) =>
              VoiceChallengeWidget(onPassed: onPass, onFailed: onFail),
        );
      case ChallengeType.random:
        return _showChallenge(ChallengeService.randomChallenge());
    }
  }

  Future<bool> _showMathChallenge() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: MathChallengeWidget(
          difficulty: _mathDifficulty,
          isBossMode: _isBossMode,
          onCompleted: (wrongCount, totalMs, quickXp) {
            Navigator.pop(ctx, {'success': true, 'wrongCount': wrongCount, 'quickXp': quickXp});
          },
          onFailed: () => Navigator.pop(ctx, {'success': false}),
        ),
      ),
    );
    if (result == null) return false;
    if (result['success'] == true) {
      _wrongAnswers = (result['wrongCount'] as int?) ?? 0;
      _quickSolveXp = (result['quickXp'] as int?) ?? 0;
      if (_quickSolveXp > 0) await SmartAlarmService.addXp(_quickSolveXp);
      return true;
    }
    return false;
  }

  Future<bool> _showOverlayChallenge(
    Widget Function(VoidCallback onPass, VoidCallback onFail) builder,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: builder(
          () => Navigator.pop(ctx, true),
          () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showShakeChallenge() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: ShakeChallengeWidget(onPassed: () => Navigator.pop(ctx, true)),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showBarcodeChallenge() async {
    final alarm = AlarmService.findByIntId(_alarmId);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 400,
          child: BarcodeChallengeWidget(
            lockedQrCode: alarm?.savedQrCode,
            onPassed: () => Navigator.pop(ctx, true),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showQuestChallenge(AlarmModel alarm) async {
    final steps = alarm.questSteps ??
        WakeQuest.ultimatePreset().steps.map((s) => s.challengeType).toList();
    final quest = WakeQuest.fromTypes(steps);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: QuestRunnerWidget(
          quest: quest,
          stepGoal: alarm.stepGoal,
          squatReps: alarm.squatReps,
          lockedQrCode: alarm.savedQrCode,
          onCompleted: () => Navigator.pop(ctx, true),
          onFailed: () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showStepCounterChallenge() async {
    final alarm = AlarmService.findByIntId(_alarmId);
    final stepGoal = alarm?.stepGoal ?? 20;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: StepCounterChallengeWidget(
          stepGoal: stepGoal,
          onPassed: () => Navigator.pop(ctx, true),
          onFailed: () => Navigator.pop(ctx, false),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showEyeOpenChallenge() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 420,
          child: EyeOpenChallengeWidget(
            onPassed: () => Navigator.pop(ctx, true),
            onFailed: () => Navigator.pop(ctx, false),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showPhotoProofChallenge() async {
    final alarm = AlarmService.findByIntId(_alarmId);
    final references = PhotoHash.decode(alarm?.photoProofHashes);

    // Nothing registered — don't show a challenge that can never pass.
    if (references.isEmpty) return _showMathChallenge();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: PhotoProofChallengeWidget(
          referenceHashes: references,
          onPassed: () => Navigator.pop(ctx, true),
          onUnmatched: () => Navigator.pop(ctx, false),
        ),
      ),
    );

    // Couldn't find the scene (bad light, moved furniture): fall back to math
    // rather than leaving the alarm ringing with no way out.
    if (result == true) return true;
    return _showMathChallenge();
  }

  Future<void> _showCelebrationSheet(DismissReward? reward, WakeScore wakeScore, int prevBest) async {
    const affirmations = [
      'Today is yours. Own it.',
      'Small wins compound into big victories.',
      'You showed up. That already matters.',
      'Progress, not perfection.',
      'Your consistency is your superpower.',
      'Rise early, think clearly.',
      'The morning belongs to the prepared.',
      'Momentum starts with one action.',
      'Discipline is choosing long-term gain.',
      'You are already ahead of yesterday.',
      'Clarity comes to those who wake with purpose.',
      'Energy follows intention.',
      'Your best work happens when others are asleep.',
      'One focused hour beats ten distracted ones.',
      'Stillness before the storm makes leaders.',
      'Sleep debt paid. Day unlocked.',
      'The early riser sets the pace.',
      'What you do first shapes what you do next.',
      'This moment is the start of something.',
      'Grit is grown in mornings like this.',
    ];
    final todayIndex = DateTime.now()._dayOfYear % affirmations.length;
    final affirmation = affirmations[todayIndex];
    final mood = await SmartAlarmService.getLatestMoodCheckIn();
    final now = DateTime.now();
    final checkInDoneToday = mood != null &&
        mood.at.year == now.year && mood.at.month == now.month && mood.at.day == now.day;
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Icon(
              (reward != null &&
                      (reward.newlyUnlockedBadges.isNotEmpty || reward.hitStreakMilestone != null))
                  ? Icons.emoji_events_rounded
                  : Icons.wb_sunny_rounded,
              size: 56,
              color: const Color(0xFF22C55E),
            ),
            const SizedBox(height: 8),
            if (reward != null) ...[
              Text(_personality.wakeMessage, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _personality.primaryColor))
                  .animate().fadeIn(duration: 300.ms),
              const SizedBox(height: 12),
              Text('+${reward.xpEarned + _quickSolveXp} XP',
                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: Color(0xFF22C55E)))
                  .animate().scale(begin: const Offset(0.5, 0.5), duration: 400.ms, curve: Curves.elasticOut).fadeIn(duration: 200.ms),
              if (_quickSolveXp > 0)
                Text('+$_quickSolveXp Quick-Solve Bonus!',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(SmartAlarmService.levelLabel(reward.totalXp),
                style: const TextStyle(fontSize: 16, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              const SizedBox(height: 14),
              if (reward.hitStreakMilestone != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFEF4444)]),
                    borderRadius: BorderRadius.circular(16)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('🔥', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Text('${reward.hitStreakMilestone}-Day Milestone!',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ).animate().slideY(begin: -0.2, end: 0, duration: 400.ms).fadeIn(),
              if (reward.comebackBonus != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFC7D2FE))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('💫', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text('Comeback Bonus +${reward.comebackBonus} XP!',
                      style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fadeIn(duration: 300.ms),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: reward.stats.currentStreak >= 7 ? const Color(0xFFFFF7ED) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: reward.stats.currentStreak >= 7 ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(reward.stats.currentStreak >= 30 ? '🔥🔥🔥'
                    : reward.stats.currentStreak >= 7 ? '🔥🔥'
                    : reward.stats.currentStreak >= 3 ? '🔥' : '⭐',
                    style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 6),
                  Text('${reward.stats.currentStreak}-day streak',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ]),
              ),
              const SizedBox(height: 14),
              _WakeScoreCard(score: wakeScore, isNewBest: wakeScore.total > prevBest),
              if (reward.newlyUnlockedBadges.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...reward.newlyUnlockedBadges.map((badge) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEFCE8),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A))),
                    child: Row(children: [
                      const Text('🏅', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        'Badge: ${SmartAlarmService.badgeDisplayName(badge) ?? badge}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                    ]),
                  ).animate().slideX(begin: 0.3, duration: 300.ms, curve: Curves.easeOut).fadeIn(duration: 250.ms),
                )),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => ShareService.shareCard(
                    context,
                    card: ShareCardWidget(
                      data: ShareCardData(
                        streak: reward.stats.currentStreak,
                        bestStreak: reward.stats.bestStreak,
                        xp: reward.totalXp,
                        levelLabel: SmartAlarmService.levelLabel(reward.totalXp),
                        wakeScoreTotal: wakeScore.total,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.ios_share_rounded, size: 18),
                  label: const Text('Share My Streak'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    foregroundColor: const Color(0xFF22C55E),
                    side: const BorderSide(color: Color(0xFF22C55E), width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 18),
            Text('"$affirmation"', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: Color(0xFF475467))),
            const SizedBox(height: 20),
            if (!checkInDoneToday) ...[
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFF94A3B8)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                child: const Text('Do Morning Check-In')),
              const SizedBox(height: 10),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                child: const Text('Start Your Day', style: TextStyle(fontWeight: FontWeight.w700))),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                AlarmRingFlow.completeRingScreenDismiss();
                Navigator.of(context).pushNamed('/morning-checkin');
              },
              child: const Text('Quick Sleep Check-In',
                  style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final alarmId = _alarmId;
    final alarm = AlarmService.findByIntId(alarmId);
    final isHardcore = alarm?.hardcoreMode ?? false;
    final snoozeMinutes = alarm?.snoozeMinutes ?? 5;
    final maxSnoozes = alarm?.maxSnoozes ?? 0;
    final snoozeLimitReached = !canSnoozeAgain(
      used: AlarmRingFlow.snoozeCountFor(alarmId),
      maxSnoozes: maxSnoozes,
    );
    final screenWidth = MediaQuery.of(context).size.width;
    final dismissThreshold = screenWidth * 0.40;
    final isDismissDir = _dragDx > 0;
    final isSnoozeDir = _dragDx < 0;
    final dragProgress = (_dragDx.abs() / dismissThreshold).clamp(0.0, 1.0);

    Color bgColor = const Color(0xFFF8FAFC);
    if (isDismissDir) {
      bgColor = Color.lerp(const Color(0xFFF8FAFC), const Color(0xFFDCFCE7), dragProgress)!;
    } else if (isSnoozeDir) {
      bgColor = Color.lerp(const Color(0xFFF8FAFC), const Color(0xFFFEF2F2), dragProgress)!;
    }

    Widget body = GestureDetector(
      onHorizontalDragUpdate: (d) {
        if (_isDismissing) return;
        setState(() {
          _dragDx = (_dragDx + d.delta.dx).clamp(-dismissThreshold * 1.2, dismissThreshold * 1.2);
        });
      },
      onHorizontalDragEnd: (d) {
        if (_isDismissing) return;
        if (_dragDx >= dismissThreshold) {
          _triggerDismiss(alarmId);
        } else if (_dragDx <= -dismissThreshold) {
          setState(() => _dragDx = 0.0);
          if (snoozeLimitReached) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No more snoozes — time to get up!')),
            );
          } else {
            AlarmRingFlow.snoozeAlarm(alarmId);
          }
        } else {
          setState(() => _dragDx = 0.0);
        }
      },
      onHorizontalDragCancel: () => setState(() => _dragDx = 0.0),
      child: Stack(
        children: [
          Positioned(
            left: 24, top: 0, bottom: 0,
            child: AnimatedOpacity(
              opacity: isSnoozeDir ? dragProgress : 0,
              duration: Duration.zero,
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bedtime_rounded, size: 40, color: Color(0xFFEF4444)),
                  SizedBox(height: 6),
                  Text('SNOOZE', style: TextStyle(fontSize: 11, letterSpacing: 2, color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          Positioned(
            right: 24, top: 0, bottom: 0,
            child: AnimatedOpacity(
              opacity: isDismissDir ? dragProgress : 0,
              duration: Duration.zero,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, size: 40, color: _personality.primaryColor),
                  const SizedBox(height: 6),
                  Text('DISMISS', style: TextStyle(fontSize: 11, letterSpacing: 2, color: _personality.primaryColor, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Transform.translate(
              offset: Offset(_dragDx * 0.15, 0),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 30),
                child: Column(
                  children: [
                    if (isHardcore)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.only(bottom: 6),
                        decoration: BoxDecoration(color: const Color(0xFF7C3AED), borderRadius: BorderRadius.circular(12)),
                        child: const Text('🔒 HARDCORE MODE — Back button disabled', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1, fontSize: 11)),
                      ).animate().fadeIn(duration: 400.ms),
                    if (_isBossMode)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(12)),
                        child: const Text('BOSS MODE', textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
                      ).animate().shake(duration: 600.ms),
                    if (alarm?.gentleWake == true && _gentleSecondsLeft > 0)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFfbbf24), Color(0xFFf97316)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '🌅 Gentle Wake — ${_gentleSecondsLeft}s remaining',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(alarm?.timeLabel ?? '06:30',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 90, fontWeight: FontWeight.w400, color: _personality.primaryColor)),
                    Text(alarm?.periodLabel ?? 'AM',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontSize: 52, color: _personality.primaryColor.withValues(alpha: 0.5))),
                    const SizedBox(height: 12),
                    Text(
                      alarm?.tag == 'nap_timer'
                          ? 'Nap Over! 😴'
                          : (alarm?.label ?? 'Wake Up'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 24, color: const Color(0xFF667085))),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: _personality.accentColor, borderRadius: BorderRadius.circular(999)),
                      child: Text('${_personality.emoji} ${_personality.name} · ${alarm?.repeatLabel ?? 'Once'}',
                        style: TextStyle(fontSize: 13, color: _personality.primaryColor, fontWeight: FontWeight.w600)),
                    ),
                    const Spacer(),
                    Transform.translate(
                      offset: Offset(_dragDx * 0.05, 0),
                      child: Container(
                        width: 220, height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: _personality.primaryColor.withValues(alpha: 0.2), width: 3)),
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _ringController,
                            builder: (context, _) => Stack(
                              alignment: Alignment.center,
                              children: [
                                _RadiatingRing(progress: _ringController.value, baseRadius: 55, color: _personality.primaryColor),
                                _RadiatingRing(progress: (_ringController.value + 0.5) % 1.0, baseRadius: 55, color: _personality.primaryColor),
                                ScaleTransition(
                                  scale: Tween<double>(begin: 0.92, end: 1.08).animate(_pulseController),
                                  child: Container(
                                    width: 140, height: 140,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _personality.accentColor,
                                      border: Border.all(color: _personality.primaryColor, width: 2)),
                                    child: Icon(Icons.notifications_active_rounded, size: 52, color: _personality.primaryColor),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Column(children: [
                          Icon(Icons.chevron_left_rounded, color: Color(0xFFCBD5E1), size: 24),
                          Text('Snooze', style: TextStyle(fontSize: 11, color: Color(0xFFCBD5E1), letterSpacing: 1)),
                        ]),
                        Column(children: [
                          Icon(Icons.chevron_right_rounded, color: _personality.primaryColor.withValues(alpha: 0.4), size: 24),
                          Text('Dismiss', style: TextStyle(fontSize: 11, color: _personality.primaryColor.withValues(alpha: 0.4), letterSpacing: 1)),
                        ]),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: (_isDismissing || snoozeLimitReached)
                                ? null
                                : () async {
                                    final snoozed =
                                        await AlarmRingFlow.snoozeAlarm(alarmId);
                                    if (!snoozed && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'No more snoozes — time to get up!'),
                                        ),
                                      );
                                    }
                                  },
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(62),
                              side: const BorderSide(color: Colors.black, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                            child: Text(snoozeLimitReached
                                ? 'No more snoozes'
                                : 'Snooze · $snoozeMinutes min')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isDismissing ? null : () => _triggerDismiss(alarmId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _personality.primaryColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(62),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                            child: const Text('Stop Alarm')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // sunriseWake is the dedicated setting, but gentleWake alarms have always
    // shown the gradient — keeping them included avoids silently removing it
    // from alarms that already had it.
    if (alarm?.sunriseWake == true || alarm?.gentleWake == true) {
      body = SunriseGradient(
        durationSeconds: alarm!.gentleWakeDurationSeconds,
        // Only the explicit setting drives the device's own brightness.
        rampBrightness: alarm.sunriseWake,
        child: body,
      );
    } else {
      body = ColoredBox(color: bgColor, child: body);
    }

    // Hardcore Mode: wrap with PopScope to block back navigation
    if (isHardcore) {
      return PopScope(
        canPop: false,
        child: Scaffold(body: body),
      );
    }
    return Scaffold(body: body);
  }
}

class _WakeScoreCard extends StatelessWidget {
  const _WakeScoreCard({required this.score, required this.isNewBest});
  final WakeScore score;
  final bool isNewBest;

  @override
  Widget build(BuildContext context) {
    final color = score.total >= 80 ? const Color(0xFF22C55E)
        : score.total >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Row(children: [
          const Text('Wake Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFEFCE8),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFFDE68A))),
              child: const Text('New Best!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: score.total / 100.0, strokeWidth: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: AlwaysStoppedAnimation(color)),
              Text('${score.total}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, color: color)),
            ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ScoreBar(label: 'Speed', value: score.speedPoints, max: 25, color: const Color(0xFF6366F1)),
            _ScoreBar(label: 'Math', value: score.accuracyPoints, max: 25, color: const Color(0xFF22C55E)),
            _ScoreBar(label: 'Snooze', value: score.snoozePoints, max: 25, color: const Color(0xFFF59E0B)),
            _ScoreBar(label: 'Mood', value: score.moodPoints, max: 25, color: const Color(0xFFEC4899)),
          ])),
        ]),
      ]),
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({required this.label, required this.value, required this.max, required this.color});
  final String label;
  final int value;
  final int max;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / max,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6))),
        const SizedBox(width: 6),
        Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _RadiatingRing extends StatelessWidget {
  const _RadiatingRing({required this.progress, required this.baseRadius, required this.color});
  final double progress;
  final double baseRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final radius = baseRadius + (progress * 55);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: opacity * 0.35), width: 1.5)));
  }
}

extension on DateTime {
  int get _dayOfYear => difference(DateTime(year, 1, 1)).inDays;
}
