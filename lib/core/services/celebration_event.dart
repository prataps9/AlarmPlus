enum CelebrationKind {
  levelUp,
  badgeUnlocked,
  streakMilestone,
  streakFrozen,
  dailyGoalMet,
  questCompleted,
  allQuestsCompleted,
}

class CelebrationEvent {
  const CelebrationEvent._(
    this.kind, {
    this.level,
    this.badgeId,
    this.streakDays,
    this.questTitle,
    this.gems,
    this.goalXp,
  });

  final CelebrationKind kind;
  final int? level;
  final String? badgeId;
  final int? streakDays;
  final String? questTitle;
  final int? gems;
  final int? goalXp;

  /// Whether this event deserves a confetti burst. A streak freeze saving
  /// you from a missed alarm is good news, but not a party.
  bool get isFestive => kind != CelebrationKind.streakFrozen;

  factory CelebrationEvent.levelUp(int level) =>
      CelebrationEvent._(CelebrationKind.levelUp, level: level);

  factory CelebrationEvent.badgeUnlocked(String badgeId) =>
      CelebrationEvent._(CelebrationKind.badgeUnlocked, badgeId: badgeId);

  factory CelebrationEvent.streakMilestone(int days) =>
      CelebrationEvent._(CelebrationKind.streakMilestone, streakDays: days);

  factory CelebrationEvent.streakFrozen(int days) =>
      CelebrationEvent._(CelebrationKind.streakFrozen, streakDays: days);

  factory CelebrationEvent.dailyGoalMet(int goalXp) =>
      CelebrationEvent._(CelebrationKind.dailyGoalMet, goalXp: goalXp);

  factory CelebrationEvent.questCompleted(String title, int gems) =>
      CelebrationEvent._(CelebrationKind.questCompleted, questTitle: title, gems: gems);

  factory CelebrationEvent.allQuestsCompleted(int gems) =>
      CelebrationEvent._(CelebrationKind.allQuestsCompleted, gems: gems);
}

/// Lets a screen with its own detailed celebration UI (e.g. the alarm dismiss
/// sheet) suppress the global [CelebrationOverlayHost] banner while it's
/// showing, without suppressing the confetti burst itself.
class CelebrationBus {
  CelebrationBus._();

  static bool mutePresentation = false;
}
