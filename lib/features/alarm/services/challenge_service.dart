import 'dart:math';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';

class ChallengeService {
  static final _rng = Random();

  static ChallengeType pickChallenge(AlarmModel alarm) {
    final type = alarm.challengeType;
    if (type == null || type == ChallengeType.random) {
      return randomChallenge();
    }
    return type;
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
      case ChallengeType.random:
        return 'Random';
    }
  }
}
