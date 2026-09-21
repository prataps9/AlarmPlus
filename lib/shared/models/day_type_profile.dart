/// The kind of day an alarm belongs to.
///
/// Used two ways: as a preset that fills in sensible defaults when creating an
/// alarm, and as the grouping an alarm is stored under so the list can be
/// organised — and enabled or disabled — a whole routine at a time.
enum DayTypeProfile { workday, gym, weekend, travel }

extension DayTypeProfileLabel on DayTypeProfile {
  String get label {
    switch (this) {
      case DayTypeProfile.workday:
        return 'Workday';
      case DayTypeProfile.gym:
        return 'Gym';
      case DayTypeProfile.weekend:
        return 'Weekend';
      case DayTypeProfile.travel:
        return 'Travel';
    }
  }
}
