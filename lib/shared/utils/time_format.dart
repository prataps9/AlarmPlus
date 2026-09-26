/// Plain-language time phrasing shared by the clock screens.
class TimeFormat {
  const TimeFormat._();

  /// "Alarm in 7 hr 20 min", the line standard clock apps show under the
  /// alarm list. Rounds up to the next minute so "in 0 min" never appears.
  static String alarmIn(Duration? untilNext) {
    if (untilNext == null) return 'No alarms set';
    final totalMinutes = (untilNext.inSeconds / 60).ceil().clamp(1, 1 << 30);
    final days = totalMinutes ~/ (24 * 60);
    final hours = (totalMinutes % (24 * 60)) ~/ 60;
    final minutes = totalMinutes % 60;
    final parts = <String>[
      if (days > 0) '$days ${days == 1 ? 'day' : 'days'}',
      if (hours > 0) '$hours hr',
      if (minutes > 0 && days == 0) '$minutes min',
    ];
    return 'Alarm in ${parts.join(' ')}';
  }

  /// Stopwatch / timer readout: `mm:ss.cc`, or `h:mm:ss.cc` past an hour.
  static String stopwatch(Duration d, {bool centis = true}) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final cs = (d.inMilliseconds.remainder(1000) ~/ 10);
    String two(int v) => v.toString().padLeft(2, '0');
    final base = h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
    return centis ? '$base.${two(cs)}' : base;
  }

  /// Offset of a city from local time: "Same time", "+5 hr 30 min",
  /// "−3 hr".
  static String offsetFromLocal(Duration diff) {
    if (diff == Duration.zero) return 'Same time';
    final sign = diff.isNegative ? '−' : '+';
    final abs = diff.abs();
    final h = abs.inHours;
    final m = abs.inMinutes.remainder(60);
    final parts = [if (h > 0) '$h hr', if (m > 0) '$m min'];
    return '$sign${parts.join(' ')}';
  }
}
