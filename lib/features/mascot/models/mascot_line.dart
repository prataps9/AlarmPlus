import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';

/// One thing Pip says, and the face Pip makes while saying it.
class MascotLine {
  const MascotLine(this.mood, this.text);

  final MascotMood mood;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is MascotLine && other.mood == mood && other.text == text;

  @override
  int get hashCode => Object.hash(mood, text);

  @override
  String toString() => 'MascotLine($mood, "$text")';
}

/// Picks Pip's Home-screen greeting. Pure so it can be unit tested; the
/// order of the checks is the priority order (a streak at risk beats a
/// cheerful good-morning).
class MascotLines {
  const MascotLines._();

  static MascotLine homeGreeting({
    required DateTime now,
    required int streak,
    required bool hasUpcomingAlarm,
    required int nextMilestone,
    String? nextAlarmLabel,
  }) {
    final hour = now.hour;
    final lateNight = hour >= 22 || hour < 4;

    if (!hasUpcomingAlarm && streak > 0) {
      return MascotLine(
        MascotMood.worried,
        'No alarm set! Your $streak-day streak needs one for tomorrow.',
      );
    }
    if (!hasUpcomingAlarm) {
      return const MascotLine(
        MascotMood.waving,
        "Hi, I'm Pip! Set your first alarm and let's start a streak.",
      );
    }
    if (lateNight) {
      return MascotLine(
        MascotMood.sleepy,
        nextAlarmLabel == null
            ? "It's late. Put the phone down, I'll wake you up."
            : "It's late. Sleep now, I'll wake you at $nextAlarmLabel.",
      );
    }
    if (streak > 0 && nextMilestone - streak == 1) {
      return MascotLine(
        MascotMood.proud,
        'One more wake-up to your $nextMilestone-day milestone!',
      );
    }
    if (hour >= 4 && hour < 12) {
      return MascotLine(
        MascotMood.cheering,
        streak > 0
            ? 'Good morning! $streak-day streak and counting.'
            : 'Good morning! Today is day one of your streak.',
      );
    }
    return MascotLine(
      MascotMood.happy,
      nextAlarmLabel == null
          ? "You're all set. See you in the morning!"
          : 'All set. See you at $nextAlarmLabel!',
    );
  }
}
