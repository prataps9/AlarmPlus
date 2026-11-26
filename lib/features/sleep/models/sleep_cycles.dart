/// Wake times that land at the end of a sleep cycle. Waking between cycles,
/// rather than in the middle of deep sleep, is what makes a morning feel
/// easy; one cycle is roughly 90 minutes.
class SleepCycles {
  const SleepCycles._();

  static const cycleLength = Duration(minutes: 90);

  /// Average time it takes to fall asleep.
  static const fallAsleep = Duration(minutes: 15);

  /// 4, 5 and 6 cycles: 6 h, 7.5 h and 9 h of sleep.
  static const suggestedCycles = [4, 5, 6];

  /// Wake times for someone going to bed at [bedtime], rounded up to the
  /// next 5 minutes so they read like times people set.
  static List<({int cycles, DateTime wakeAt})> wakeTimes(DateTime bedtime) => [
        for (final cycles in suggestedCycles)
          (
            cycles: cycles,
            wakeAt: _roundUpTo5(bedtime.add(fallAsleep + cycleLength * cycles)),
          ),
      ];

  /// Hours of sleep [cycles] gives, as shown next to a wake time.
  static String sleepLabel(int cycles) {
    final minutes = cycleLength.inMinutes * cycles;
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h.${m ~/ 6} h';
  }

  static DateTime _roundUpTo5(DateTime t) {
    final whole = DateTime(t.year, t.month, t.day, t.hour, t.minute);
    final extra = (5 - whole.minute % 5) % 5;
    final hasSeconds = t.second > 0 || t.millisecond > 0;
    final add = extra == 0 && hasSeconds ? 5 : extra;
    return whole.add(Duration(minutes: add));
  }
}
