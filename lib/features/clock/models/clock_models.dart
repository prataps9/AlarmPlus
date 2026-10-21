import 'dart:convert';

import 'package:timezone/timezone.dart' as tz;

// ─── World clock ───────────────────────────────────────────────────────────

/// A city offered in the world-clock picker.
class WorldCity {
  const WorldCity(this.name, this.country, this.tzId);

  final String name;
  final String country;

  /// IANA zone id, e.g. `Asia/Kolkata`.
  final String tzId;

  static const all = <WorldCity>[
    WorldCity('Auckland', 'New Zealand', 'Pacific/Auckland'),
    WorldCity('Sydney', 'Australia', 'Australia/Sydney'),
    WorldCity('Tokyo', 'Japan', 'Asia/Tokyo'),
    WorldCity('Seoul', 'South Korea', 'Asia/Seoul'),
    WorldCity('Beijing', 'China', 'Asia/Shanghai'),
    WorldCity('Hong Kong', 'China', 'Asia/Hong_Kong'),
    WorldCity('Singapore', 'Singapore', 'Asia/Singapore'),
    WorldCity('Bangkok', 'Thailand', 'Asia/Bangkok'),
    WorldCity('Jakarta', 'Indonesia', 'Asia/Jakarta'),
    WorldCity('Dhaka', 'Bangladesh', 'Asia/Dhaka'),
    WorldCity('Kathmandu', 'Nepal', 'Asia/Kathmandu'),
    WorldCity('New Delhi', 'India', 'Asia/Kolkata'),
    WorldCity('Mumbai', 'India', 'Asia/Kolkata'),
    WorldCity('Karachi', 'Pakistan', 'Asia/Karachi'),
    WorldCity('Dubai', 'UAE', 'Asia/Dubai'),
    WorldCity('Riyadh', 'Saudi Arabia', 'Asia/Riyadh'),
    WorldCity('Moscow', 'Russia', 'Europe/Moscow'),
    WorldCity('Istanbul', 'Türkiye', 'Europe/Istanbul'),
    WorldCity('Cairo', 'Egypt', 'Africa/Cairo'),
    WorldCity('Nairobi', 'Kenya', 'Africa/Nairobi'),
    WorldCity('Johannesburg', 'South Africa', 'Africa/Johannesburg'),
    WorldCity('Lagos', 'Nigeria', 'Africa/Lagos'),
    WorldCity('Berlin', 'Germany', 'Europe/Berlin'),
    WorldCity('Paris', 'France', 'Europe/Paris'),
    WorldCity('Madrid', 'Spain', 'Europe/Madrid'),
    WorldCity('Rome', 'Italy', 'Europe/Rome'),
    WorldCity('Amsterdam', 'Netherlands', 'Europe/Amsterdam'),
    WorldCity('London', 'United Kingdom', 'Europe/London'),
    WorldCity('Dublin', 'Ireland', 'Europe/Dublin'),
    WorldCity('Lisbon', 'Portugal', 'Europe/Lisbon'),
    WorldCity('São Paulo', 'Brazil', 'America/Sao_Paulo'),
    WorldCity('Buenos Aires', 'Argentina', 'America/Argentina/Buenos_Aires'),
    WorldCity('New York', 'United States', 'America/New_York'),
    WorldCity('Toronto', 'Canada', 'America/Toronto'),
    WorldCity('Chicago', 'United States', 'America/Chicago'),
    WorldCity('Mexico City', 'Mexico', 'America/Mexico_City'),
    WorldCity('Denver', 'United States', 'America/Denver'),
    WorldCity('Los Angeles', 'United States', 'America/Los_Angeles'),
    WorldCity('Vancouver', 'Canada', 'America/Vancouver'),
    WorldCity('Anchorage', 'United States', 'America/Anchorage'),
    WorldCity('Honolulu', 'United States', 'Pacific/Honolulu'),
  ];

  static WorldCity? byName(String name) {
    for (final c in all) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// What a world-clock row shows for [city] at the instant [nowUtc].
class CityTime {
  const CityTime({required this.wallTime, required this.offsetFromLocal, required this.dayLabel});

  /// The city's wall-clock time (fields only; don't treat as local).
  final DateTime wallTime;

  /// City offset minus local offset: how far ahead the city is.
  final Duration offsetFromLocal;

  /// "Today", "Tomorrow" or "Yesterday", relative to the local date.
  final String dayLabel;

  static CityTime of(WorldCity city, DateTime nowUtc, Duration localOffset) {
    final loc = tz.getLocation(city.tzId);
    final cityOffset = Duration(milliseconds: loc.timeZone(nowUtc.millisecondsSinceEpoch).offset);
    final wall = nowUtc.toUtc().add(cityOffset);
    final localWall = nowUtc.toUtc().add(localOffset);
    final dayDiff = DateTime.utc(wall.year, wall.month, wall.day)
        .difference(DateTime.utc(localWall.year, localWall.month, localWall.day))
        .inDays;
    return CityTime(
      wallTime: DateTime(wall.year, wall.month, wall.day, wall.hour, wall.minute, wall.second),
      offsetFromLocal: cityOffset - localOffset,
      dayLabel: switch (dayDiff) {
        > 0 => 'Tomorrow',
        < 0 => 'Yesterday',
        _ => 'Today',
      },
    );
  }
}

// ─── Stopwatch ─────────────────────────────────────────────────────────────

/// Stopwatch state as timestamps rather than a ticking counter, so it keeps
/// "running" while the app is closed and survives being killed (it is
/// persisted as JSON). Laps are stored as cumulative totals.
class StopwatchState {
  const StopwatchState({this.startedAt, this.banked = Duration.zero, this.laps = const []});

  /// Non-null while running.
  final DateTime? startedAt;

  /// Time accumulated before the current run.
  final Duration banked;

  /// Total elapsed at each lap press, oldest first.
  final List<Duration> laps;

  bool get isRunning => startedAt != null;
  bool get isPristine => !isRunning && banked == Duration.zero && laps.isEmpty;

  Duration elapsed(DateTime now) =>
      startedAt == null ? banked : banked + now.difference(startedAt!);

  StopwatchState start(DateTime now) =>
      isRunning ? this : StopwatchState(startedAt: now, banked: banked, laps: laps);

  StopwatchState pause(DateTime now) =>
      isRunning ? StopwatchState(banked: elapsed(now), laps: laps) : this;

  StopwatchState lap(DateTime now) =>
      StopwatchState(startedAt: startedAt, banked: banked, laps: [...laps, elapsed(now)]);

  static const reset = StopwatchState();

  /// Individual lap durations, oldest first.
  List<Duration> get lapSplits => [
        for (var i = 0; i < laps.length; i++) laps[i] - (i == 0 ? Duration.zero : laps[i - 1]),
      ];

  String toJson() => jsonEncode({
        'startedAt': startedAt?.millisecondsSinceEpoch,
        'banked': banked.inMilliseconds,
        'laps': laps.map((l) => l.inMilliseconds).toList(),
      });

  static StopwatchState fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return reset;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final started = m['startedAt'] as int?;
      return StopwatchState(
        startedAt: started == null ? null : DateTime.fromMillisecondsSinceEpoch(started),
        banked: Duration(milliseconds: m['banked'] as int? ?? 0),
        laps: [for (final l in (m['laps'] as List? ?? const [])) Duration(milliseconds: l as int)],
      );
    } catch (_) {
      return reset;
    }
  }
}

// ─── Timer ─────────────────────────────────────────────────────────────────

/// Countdown timer state, also timestamp-based and persisted.
class CountdownState {
  const CountdownState({required this.total, this.endsAt, this.pausedRemaining});

  /// The duration it was set to (for the progress ring).
  final Duration total;

  /// Non-null while running.
  final DateTime? endsAt;

  /// Non-null while paused.
  final Duration? pausedRemaining;

  bool get isRunning => endsAt != null;
  bool get isPaused => pausedRemaining != null;
  bool get isIdle => !isRunning && !isPaused;

  Duration remaining(DateTime now) {
    if (endsAt != null) {
      final r = endsAt!.difference(now);
      return r.isNegative ? Duration.zero : r;
    }
    return pausedRemaining ?? total;
  }

  bool isDone(DateTime now) => isRunning && !now.isBefore(endsAt!);

  /// 1.0 when just started, 0.0 when finished.
  double fraction(DateTime now) =>
      total.inMilliseconds == 0 ? 0 : remaining(now).inMilliseconds / total.inMilliseconds;

  static CountdownState startNew(Duration total, DateTime now) =>
      CountdownState(total: total, endsAt: now.add(total));

  CountdownState pause(DateTime now) =>
      isRunning ? CountdownState(total: total, pausedRemaining: remaining(now)) : this;

  CountdownState resume(DateTime now) =>
      isPaused ? CountdownState(total: total, endsAt: now.add(pausedRemaining!)) : this;

  /// "+1:00": extends a running or paused timer (and its total, so the ring
  /// doesn't jump past full).
  CountdownState extend(Duration by, DateTime now) {
    if (isRunning) return CountdownState(total: total + by, endsAt: endsAt!.add(by));
    if (isPaused) return CountdownState(total: total + by, pausedRemaining: pausedRemaining! + by);
    return this;
  }

  String toJson() => jsonEncode({
        'total': total.inMilliseconds,
        'endsAt': endsAt?.millisecondsSinceEpoch,
        'paused': pausedRemaining?.inMilliseconds,
      });

  static CountdownState? fromJson(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final ends = m['endsAt'] as int?;
      final paused = m['paused'] as int?;
      return CountdownState(
        total: Duration(milliseconds: m['total'] as int),
        endsAt: ends == null ? null : DateTime.fromMillisecondsSinceEpoch(ends),
        pausedRemaining: paused == null ? null : Duration(milliseconds: paused),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Keypad entry for the timer, the way standard clock apps do it: digits
/// shift in from the right, so typing 1-3-0 means 1 min 30 s and 1-3-0-0
/// means 13 min 0 s. At most six digits (hh mm ss).
class TimerInput {
  const TimerInput([this.digits = '']);

  final String digits;

  TimerInput type(int digit) =>
      digits.length >= 6 || (digits.isEmpty && digit == 0) ? this : TimerInput('$digits$digit');

  TimerInput backspace() =>
      digits.isEmpty ? this : TimerInput(digits.substring(0, digits.length - 1));

  String get _padded => digits.padLeft(6, '0');
  int get hours => int.parse(_padded.substring(0, 2));
  int get minutes => int.parse(_padded.substring(2, 4));
  int get seconds => int.parse(_padded.substring(4, 6));

  /// Overflowing fields carry, so "90" seconds is 1 min 30 s.
  Duration get duration => Duration(hours: hours, minutes: minutes, seconds: seconds);

  bool get isEmpty => digits.isEmpty;
}
