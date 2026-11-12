/// One-tap starting points for a new alarm: a time and the days it repeats.
/// Days use the app's numbering (1 = Monday ... 7 = Sunday).
class AlarmPreset {
  const AlarmPreset(this.label, this.hour, this.minute, this.days);

  final String label;
  final int hour;
  final int minute;
  final Set<int> days;

  static const all = <AlarmPreset>[
    AlarmPreset('Weekdays', 7, 0, {1, 2, 3, 4, 5}),
    AlarmPreset('Weekend', 9, 0, {6, 7}),
    AlarmPreset('Every day', 6, 30, {1, 2, 3, 4, 5, 6, 7}),
  ];
}

/// Which alarms "Turn all off/on" changes: only the user's own alarms whose
/// state differs, so Undo can put exactly those back.
List<String> idsToSwitch(
  Iterable<({String id, bool enabled, bool system})> alarms, {
  required bool on,
}) =>
    [
      for (final a in alarms)
        if (!a.system && a.enabled != on) a.id,
    ];
