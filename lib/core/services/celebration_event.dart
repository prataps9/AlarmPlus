enum CelebrationKind { levelUp, badgeUnlocked, streakMilestone }

class CelebrationEvent {
  const CelebrationEvent._(this.kind, {this.level, this.badgeId, this.streakDays});

  final CelebrationKind kind;
  final int? level;
  final String? badgeId;
  final int? streakDays;

  factory CelebrationEvent.levelUp(int level) =>
      CelebrationEvent._(CelebrationKind.levelUp, level: level);

  factory CelebrationEvent.badgeUnlocked(String badgeId) =>
      CelebrationEvent._(CelebrationKind.badgeUnlocked, badgeId: badgeId);

  factory CelebrationEvent.streakMilestone(int days) =>
      CelebrationEvent._(CelebrationKind.streakMilestone, streakDays: days);
}

/// Lets a screen with its own detailed celebration UI (e.g. the alarm dismiss
/// sheet) suppress the global [CelebrationOverlayHost] banner while it's
/// showing, without suppressing the confetti burst itself.
class CelebrationBus {
  CelebrationBus._();

  static bool mutePresentation = false;
}
