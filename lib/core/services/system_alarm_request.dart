import 'package:flutter/material.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

/// An alarm asked for through Android's standard `SET_ALARM` intent: Google
/// Assistant ("set an alarm for 6:30"), Wear OS, Android Auto, other apps.
/// AlarmIntentActivity.kt turns the intent's extras into a map; this is the
/// pure Dart half, so the rules are testable.
class SystemAlarmRequest {
  const SystemAlarmRequest({
    required this.time,
    required this.label,
    required this.repeatDays,
  });

  final TimeOfDay time;
  final String label;

  /// Monday = 1 … Sunday = 7, like the rest of the app. Empty: rings once.
  final List<int> repeatDays;

  static const _maxLabel = 60;

  /// Android's `Calendar` numbers days Sunday = 1 … Saturday = 7; the app
  /// uses Monday = 1 … Sunday = 7.
  static int appDay(int calendarDay) => calendarDay == 1 ? 7 : calendarDay - 1;

  /// Reads the map AlarmIntentActivity builds: `hour`, `minute`, `message`
  /// and `days` (Calendar numbers). Null when the time is missing or out of
  /// range ("7:75", hour 24): the request is ignored rather than guessed.
  static SystemAlarmRequest? parse(Map<String, dynamic> raw) {
    final hour = (raw['hour'] as num?)?.toInt();
    final minute = (raw['minute'] as num?)?.toInt() ?? 0;
    if (hour == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    final message = ((raw['message'] as String?) ?? '').trim();
    final label =
        message.length > _maxLabel ? message.substring(0, _maxLabel) : message;
    final days = <int>{
      for (final d in (raw['days'] as List?) ?? const [])
        if (d is num && d >= 1 && d <= 7) appDay(d.toInt()),
    }.toList()
      ..sort();
    return SystemAlarmRequest(
      time: TimeOfDay(hour: hour, minute: minute),
      label: label,
      repeatDays: days,
    );
  }

  /// The alarm already set for exactly this, if any: an assistant that
  /// repeats itself must not create a duplicate.
  AlarmModel? findExisting(Iterable<AlarmModel> alarms) {
    for (final a in alarms) {
      if (a.isSystem || !a.isEnabled) continue;
      final days = [...a.repeatDays]..sort();
      if (a.time.hour == time.hour &&
          a.time.minute == time.minute &&
          a.label == label &&
          _sameDays(days, repeatDays)) {
        return a;
      }
    }
    return null;
  }

  static bool _sameDays(List<int> a, List<int> b) =>
      a.length == b.length && [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((x) => x);

  /// Creates and schedules the alarm (or returns the identical one that
  /// exists), then tells the list to reload.
  Future<AlarmModel> apply() async {
    final existing = findExisting(AlarmService.getAllAlarms());
    if (existing != null) return existing;
    final alarm = AlarmService.createAlarm(
      time: time,
      label: label,
      repeatDays: repeatDays,
      isEnabled: true,
      tag: '',
    );
    await AlarmService.scheduleAlarm(alarm);
    AlarmService.notifyChanged();
    return alarm;
  }
}
