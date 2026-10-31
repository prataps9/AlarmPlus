import 'dart:math' as math;
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/features/alarm/challenges/photo_hash.dart';
import 'package:alarm_plus/features/alarm/challenges/photo_proof_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/squat_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/voice_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/barcode_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/challenges/color_clash_challenge_widget.dart';
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
import 'package:alarm_plus/core/services/morning_briefing_service.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
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
import 'package:alarm_plus/shared/utils/time_format.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';

class AlarmRingScreen extends StatefulWidget {
  const AlarmRingScreen({super.key});
  static const routeName = '/alarm-ring';

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  MathDifficulty _mathDifficulty = MathDifficulty.easy;
  DismissChallengeType _defaultChallenge = DismissChallengeType.math;
  late final AnimationController _pulseController;
  late final AnimationController _ringController;
  bool _isDismissing = false;
  PersonalityConfig _personality = PersonalityConfig.all[AlarmPersonality.gentle]!;
  int _wrongAnswers = 0;
  int _quickSolveXp = 0;
  final int _dismissStartMs = DateTime.now().millisecondsSinceEpoch;

  /// Media volume before this screen changed it, restored on dispose —
  /// otherwise every alarm left the phone's media volume at the alarm level.

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
      _defaultChallenge = challengeType;
    });
    final alarmId = _alarmId;
    if (alarmId > 0) {
      final alarm = AlarmService.findByIntId(alarmId);
      if (alarm != null && mounted) {
        final config = PersonalityConfig.forName(alarm.personality);
        setState(() => _personality = config);
        await SmartAlarmService.recordPersonalityUsed(alarm.personality);
        if (!mounted) return;
        // Volume and the fade-in are applied by the alarm plugin itself
        // (see AlarmService.scheduleAlarm); this only shows the countdown.
        if (alarm.gentleWake) _startGentleWake(alarm);
      }
      // Guardian timer is owned by AlarmRingFlow — no duplicate needed here.
    }
  }

  void _startGentleWake(AlarmModel alarm) {
    setState(() {
      _gentleSecondsLeft = alarm.gentleWakeDurationSeconds;
      _gentleWakeActive = true;
    });
    final duration = alarm.gentleWakeDurationSeconds;
    var elapsed = 0;
    Future.doWhile(() async {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted || !_gentleWakeActive) return false;
      elapsed++;
      if (mounted) setState(() => _gentleSecondsLeft = duration - elapsed);
      return elapsed < duration && _gentleWakeActive;
    });
  }

  void _stopGentleWake() {
    _gentleWakeActive = false;
  }

  @override
  void dispose() {
    _gentleWakeActive = false;
    _pulseController.dispose();
    _ringController.dispose();
    super.dispose();
  }

  /// Settings → Preview Alarm Screen opens this with no alarm. Dismissing a
  /// preview must not pay XP or record a wake-up.
  bool get _isPreview => _alarmId <= 0;

  /// Set before the first await, so a double tap (or Stop during the voice
  /// memo) can't open a second challenge and dismiss twice.
  bool _dismissInFlight = false;

  Future<void> _triggerDismiss(int alarmId) async {
    if (_isDismissing || _dismissInFlight) return;
    _dismissInFlight = true;
    // Muted for the whole dismiss→celebration-sheet sequence so the global
    // celebration banner (level-up/badge) doesn't pop up behind or before
    // this screen's own detailed sheet. Confetti still fires either way.
    CelebrationBus.mutePresentation = true;
    try {
      final alarm = AlarmService.findByIntId(alarmId);

      // The alarm's own challenge or quest; otherwise the default from
      // Settings (which may be none).
      final ChallengeType? challenge;
      if (alarm != null && alarm.challengeType != null) {
        challenge = ChallengeService.pickChallenge(alarm);
      } else {
        challenge = ChallengeService.defaultChallenge(
          _defaultChallenge,
          isPro: PremiumService.isPro.value,
        );
      }

      if ((alarm != null && alarm.questMode) || challenge != null) {
        bool passed;

        if (alarm != null && alarm.questMode) {
          passed = await _showQuestChallenge(alarm);
        } else {
          passed = await _showChallenge(challenge!);
        }

        if (!passed) return;
      }

      _stopGentleWake();
      setState(() => _isDismissing = true);
      if (_isPreview) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final reRing = await AlarmService.isWakeCheckReRing(alarmId);
      final reward = await AlarmRingFlow.stopAlarm(alarmId);
      if (!mounted) return;
      if (reRing) {
        // The wake-up was already scored and celebrated the first time.
        AlarmRingFlow.completeRingScreenDismiss();
        return;
      }
      if (alarm != null && alarm.isSystem) {
        // Nap over / arrived: no wake score, celebration or morning routine.
        AlarmRingFlow.completeRingScreenDismiss();
        return;
      }

      // The voice memo plays once the alarm has stopped; it used to play
      // under the still-ringing alarm and was barely audible.
      final memoPath = alarm?.voiceMemoPath;
      if (memoPath != null && await File(memoPath).exists()) {
        try {
          await VoiceMemoService.playMemo(memoPath);
        } catch (e) {
          debugPrint('Voice memo playback failed: $e');
        }
      }
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
      // Not awaited: it talks while the celebration sheet is up.
      unawaited(MorningBriefingService.playIfEnabled(
        dismissSeconds: dismissMs ~/ 1000,
        streakDays: reward?.stats.currentStreak ?? 0,
        wakeScore: wakeScore.total,
      ));

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
      final navigator = Navigator.of(context);
      final next = await _showCelebrationSheet(reward, wakeScore, prevBest);
      // Navigate once, after the sheet: the check-in button used to close the
      // ring screen itself, and the second close here then popped the
      // check-in it had just opened.
      AlarmRingFlow.completeRingScreenDismiss();
      navigator.pushNamed(next == _AfterWake.checkIn
          ? '/morning-checkin'
          : WakeRoutineScreen.routeName);
    } finally {
      CelebrationBus.mutePresentation = false;
      _dismissInFlight = false;
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
      case ChallengeType.colorClash:
        return _showOverlayChallenge(
          (onPass, onFail) =>
              ColorClashChallengeWidget(onPassed: onPass, onFailed: onFail),
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
      if (_quickSolveXp > 0 && !_isPreview) {
        await SmartAlarmService.addXp(_quickSolveXp);
      }
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
        // After its time limit it reports a fail; without onFailed it just
        // sat at "0" with no way on.
        child: ShakeChallengeWidget(
          onPassed: () => Navigator.pop(ctx, true),
          onFailed: () => Navigator.pop(ctx, false),
        ),
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

  Future<_AfterWake?> _showCelebrationSheet(DismissReward? reward, WakeScore wakeScore, int prevBest) async {
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
    if (!mounted) return null;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet<_AfterWake>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: scheme.surfaceContainer,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4,
              decoration: BoxDecoration(color: scheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            PipMascot(
              mood: (reward != null &&
                      (reward.newlyUnlockedBadges.isNotEmpty || reward.hitStreakMilestone != null))
                  ? MascotMood.cheering
                  : MascotMood.happy,
              size: 96,
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
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
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
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.35))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('💫', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text('Comeback Bonus +${reward.comebackBonus} XP!',
                      style: TextStyle(color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                  ]),
                ).animate().fadeIn(duration: 300.ms),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: reward.stats.currentStreak >= 7
                      ? const Color(0xFFF97316).withValues(alpha: 0.12)
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: reward.stats.currentStreak >= 7
                        ? const Color(0xFFF97316).withValues(alpha: 0.35)
                        : scheme.outlineVariant)),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
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
              style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            if (!checkInDoneToday) ...[
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx, _AfterWake.checkIn),
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
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40))),
                child: const Text('Start Your Day', style: TextStyle(fontWeight: FontWeight.w700))),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx, _AfterWake.checkIn),
              child: const Text('Quick Sleep Check-In',
                  style: TextStyle(color: Color(0xFF6366F1))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snoozeButton(
    BuildContext context, {
    required int alarmId,
    required int snoozeMinutes,
    required bool limitReached,
  }) {
    return FilledButton(
      onPressed: (_isDismissing || limitReached)
          ? null
          : () async {
              HapticFeedback.lightImpact();
              final snoozed = await AlarmRingFlow.snoozeAlarm(alarmId);
              if (!snoozed && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('No more snoozes — time to get up!')),
                );
              }
            },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.14),
        foregroundColor: Colors.white,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.06),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.35),
        minimumSize: const Size.fromHeight(72),
        shape: const StadiumBorder(),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            limitReached ? 'No snoozes left' : 'Snooze',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
          ),
          if (!limitReached)
            Text('$snoozeMinutes min', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _stopButton(int alarmId) {
    return FilledButton(
      onPressed: _isDismissing
          ? null
          : () {
              HapticFeedback.mediumImpact();
              _triggerDismiss(alarmId);
            },
      style: FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B1220),
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.3),
        minimumSize: const Size.fromHeight(72),
        shape: const StadiumBorder(),
      ),
      child: const Text('Stop',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
    );
  }

  /// Whether Stop leads into a wake challenge (the alarm's own, a quest, or
  /// the one chosen in Settings). Mirrors the choice in [_triggerDismiss].
  bool _needsChallenge(AlarmModel? alarm) {
    if (alarm != null && (alarm.questMode || alarm.challengeType != null)) {
      return true;
    }
    return ChallengeService.defaultChallenge(
          _defaultChallenge,
          isPro: PremiumService.isPro.value,
        ) !=
        null;
  }

  /// The stock alarm screen is dark whatever the app theme: it is read half
  /// asleep, at night.
  static const _ringBackground = Color(0xFF05070D);

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
    final accent = _personality.primaryColor;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final rawLabel = alarm?.label.trim() ?? '';
    final label = alarm?.tag == AlarmModel.napTag
        ? 'Nap Over! 😴'
        : (rawLabel.isEmpty ? 'Alarm' : rawLabel);

    Widget banner(Widget child) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: child,
        );

    Widget body = Stack(
      children: [
        // A soft glow behind the time that breathes with the ring.
        Positioned.fill(
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) => DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 0.95,
                    colors: [
                      accent.withValues(
                          alpha: 0.10 + 0.14 * _pulseController.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
            child: Column(
              children: [
                if (isHardcore)
                  banner(Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('🔒 HARDCORE MODE — Back button disabled',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            fontSize: 11)),
                  ).animate().fadeIn(duration: 400.ms)),
                if (_isBossMode)
                  banner(Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Text('BOSS MODE',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            fontSize: 13)),
                  ).animate().shake(duration: 600.ms)),
                if (alarm?.gentleWake == true && _gentleSecondsLeft > 0)
                  banner(Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFFfbbf24), Color(0xFFf97316)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '🌅 Gentle Wake — ${_gentleSecondsLeft}s remaining',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13),
                    ),
                  )),
                const SizedBox(height: 6),
                // Swinging bell and today's date, like the stock clock.
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _ringController,
                      builder: (context, child) => Transform.rotate(
                        angle: _isDismissing || reduceMotion
                            ? 0
                            : math.sin(_ringController.value * math.pi * 8) *
                                0.3,
                        alignment: Alignment.topCenter,
                        child: child,
                      ),
                      child: Icon(Icons.notifications_active_rounded,
                          size: 22, color: accent),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          DateFormat('EEE, d MMM').format(DateTime.now()),
                          style: TextStyle(
                              fontSize: 16,
                              letterSpacing: 0.3,
                              color: Colors.white.withValues(alpha: 0.7)),
                        ),
                      ),
                    ),
                  ],
                ),
                // The time and label sit centred in the space between the
                // date and the buttons, and scroll only if a huge system
                // font leaves no room.
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                // The current time, live: after a snooze the alarm's set
                // time would be stale.
                const _LiveClock(color: Colors.white),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ).animate().fadeIn(duration: 500.ms).slideY(
                    begin: 0.15, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),
                const SizedBox(height: 8),
                Text(
                  '${_personality.emoji} ${_personality.name} · ${alarm?.repeatLabel ?? 'Once'}',
                  style: TextStyle(
                      fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_needsChallenge(alarm))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      'Finish the wake challenge to stop',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.55)),
                    ),
                  ),
                Builder(builder: (context) {
                  final snooze = _snoozeButton(
                    context,
                    alarmId: alarmId,
                    snoozeMinutes: snoozeMinutes,
                    limitReached: snoozeLimitReached,
                  );
                  final stop = _stopButton(alarmId);
                  // Side by side stops fitting at very large system text.
                  final stacked =
                      MediaQuery.textScalerOf(context).scale(1) > 1.6;
                  return stacked
                      ? Column(children: [
                          SizedBox(width: double.infinity, child: stop),
                          const SizedBox(height: 12),
                          SizedBox(width: double.infinity, child: snooze),
                        ])
                      : Row(children: [
                          Expanded(child: snooze),
                          const SizedBox(width: 14),
                          Expanded(child: stop),
                        ]);
                }).animate().fadeIn(duration: 450.ms).slideY(
                    begin: 0.25,
                    end: 0,
                    duration: 450.ms,
                    curve: Curves.easeOutCubic),
              ],
            ),
          ),
        ),
      ],
    );

    // Gentle wake alarms rise through the sunrise gradient instead.
    if (alarm?.gentleWake == true) {
      body = SunriseGradient(
        durationSeconds: alarm!.gentleWakeDurationSeconds,
        child: body,
      );
    } else {
      body = ColoredBox(color: _ringBackground, child: body);
    }

    // A ringing alarm is ended by Stop or Snooze, never by Back: Back used
    // to close the screen while the alarm kept ringing, with no way to get
    // the screen back. (Hardcore already blocked it; a preview allows it.)
    return PopScope(
      canPop: _isPreview,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Light status-bar icons on the dark screen.
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: _ringBackground,
          body: body,
        ),
      ),
    );
  }
}

class _WakeScoreCard extends StatelessWidget {
  const _WakeScoreCard({required this.score, required this.isNewBest});
  final WakeScore score;
  final bool isNewBest;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = score.total >= 80 ? const Color(0xFF22C55E)
        : score.total >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant)),
      child: Column(children: [
        Row(children: [
          const Text('Wake Score', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          const Spacer(),
          if (isNewBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))),
              child: Text('New Best!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E)))),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 64, height: 64,
            child: Stack(alignment: Alignment.center, children: [
              CircularProgressIndicator(
                value: score.total / 100.0, strokeWidth: 6,
                backgroundColor: scheme.outlineVariant,
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
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        SizedBox(width: 44, child: Text(label, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))),
        Expanded(child: ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value / max,
            backgroundColor: scheme.outlineVariant,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6))),
        const SizedBox(width: 6),
        Text('$value', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

extension on DateTime {
  int get _dayOfYear => difference(DateTime(year, 1, 1)).inDays;
}

/// The current time in big type, ticking every second, in the phone's
/// 12/24-hour format.
class _LiveClock extends StatefulWidget {
  const _LiveClock({required this.color});

  final Color color;

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final c = TimeFormat.clock(now.hour, now.minute,
        use24h: MediaQuery.alwaysUse24HourFormatOf(context));
    // Thin, tabular figures like the stock clock; scaled down on narrow
    // phones or large system text instead of overflowing.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            c.time,
            style: TextStyle(
              fontSize: 112,
              height: 1.0,
              fontWeight: FontWeight.w200,
              letterSpacing: -2,
              color: widget.color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (c.period != null) ...[
            const SizedBox(width: 8),
            Text(
              c.period!,
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w300,
                color: widget.color.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Where to go once the post-dismiss sheet closes.
enum _AfterWake { checkIn }
