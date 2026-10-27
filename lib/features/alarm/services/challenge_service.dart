import 'dart:math';

import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';

class ChallengeService {
  static final _rng = Random();

  /// The alarm's own challenge; "Random" picks one each time. Null (the
  /// editor's "Default") isn't handled here: see [defaultChallenge].
  static ChallengeType pickChallenge(AlarmModel alarm) {
    final type = alarm.challengeType;
    if (type == ChallengeType.random) return randomChallenge();
    return type ?? ChallengeType.math;
  }

  /// The challenge for an alarm left on "Default", from Settings → Wake
  /// Challenge: null means no challenge. Choosing memory, QR or steps there
  /// is Pro; without Pro (e.g. after a refund) those fall back to math.
  /// It used to pick a random challenge, ignoring the setting.
  static ChallengeType? defaultChallenge(
    DismissChallengeType setting, {
    required bool isPro,
  }) {
    switch (setting) {
      case DismissChallengeType.none:
        return null;
      case DismissChallengeType.math:
        return ChallengeType.math;
      case DismissChallengeType.memory:
        return isPro ? ChallengeType.memoryPattern : ChallengeType.math;
      case DismissChallengeType.qr:
        return isPro ? ChallengeType.barcodeScan : ChallengeType.math;
      case DismissChallengeType.steps:
        return isPro ? ChallengeType.stepCounter : ChallengeType.math;
    }
  }

  /// Types that "Random" may choose. Excludes anything needing setup ahead of
  /// time (a registered QR code or photo) or hardware that may be absent.
  static const pickable = [
    ChallengeType.math,
    ChallengeType.memoryPattern,
    ChallengeType.shakeToWake,
    ChallengeType.typing,
    ChallengeType.trivia,
    ChallengeType.wordScramble,
    ChallengeType.voiceRepeat,
    ChallengeType.colorClash,
  ];

  /// Types offered when building a multi-step quest. Broader than [pickable]
  /// because the user is choosing each step deliberately.
  static const questPickable = [
    ChallengeType.math,
    ChallengeType.memoryPattern,
    ChallengeType.shakeToWake,
    ChallengeType.typing,
    ChallengeType.trivia,
    ChallengeType.wordScramble,
    ChallengeType.squatReps,
    ChallengeType.voiceRepeat,
    ChallengeType.colorClash,
  ];

  static ChallengeType randomChallenge() {
    return pickable[_rng.nextInt(pickable.length)];
  }

  static String label(ChallengeType type) {
    switch (type) {
      case ChallengeType.math:
        return 'Math';
      case ChallengeType.memoryPattern:
        return 'Memory Pattern';
      case ChallengeType.shakeToWake:
        return 'Shake to Wake';
      case ChallengeType.typing:
        return 'Typing';
      case ChallengeType.barcodeScan:
        return 'Barcode Scan';
      case ChallengeType.trivia:
        return 'Trivia';
      case ChallengeType.wordScramble:
        return 'Word Scramble';
      case ChallengeType.stepCounter:
        return 'Step Counter';
      case ChallengeType.eyeOpen:
        return 'Eyes Open';
      case ChallengeType.squatReps:
        return 'Squats';
      case ChallengeType.photoProof:
        return 'Photo Proof';
      case ChallengeType.voiceRepeat:
        return 'Read Aloud';
      case ChallengeType.colorClash:
        return 'Color Clash';
      case ChallengeType.random:
        return 'Random';
    }
  }
}
