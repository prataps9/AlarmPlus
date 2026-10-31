import 'package:alarm_plus/features/alarm/models/alarm_model.dart';

/// One time an alarm will ring.
typedef UpcomingRing = ({AlarmModel alarm, DateTime at});

/// Every ring in [window] after [now], soonest first, so the user can see
/// exactly what the week holds once skips, pauses and dates are applied.
List<UpcomingRing> upcomingRings(
  Iterable<AlarmModel> alarms,
  DateTime now, {
  Duration window = const Duration(days: 7),
}) {
  final end = now.add(window);
  final rings = <UpcomingRing>[];
  for (final alarm in alarms) {
    if (!alarm.isEnabled || alarm.isSystem || alarm.isExpiredAt(now)) continue;
    var from = now;
    // Safety bound: at most one ring per day in the window.
    for (var i = 0; i <= window.inDays + 1; i++) {
      final at = alarm.nextDateTimeFrom(from);
      if (at.isBefore(now) || !at.isBefore(end)) break;
      rings.add((alarm: alarm, at: at));
      if (alarm.repeatDays.isEmpty) break; // a one-off rings once
      from = at.add(const Duration(minutes: 1));
    }
  }
  rings.sort((a, b) => a.at.compareTo(b.at));
  return rings;
}
