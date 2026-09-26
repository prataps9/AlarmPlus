import 'package:flutter/material.dart';

class BedtimeSchedule {
  const BedtimeSchedule({
    required this.targetBedtime,
    this.windDownMinutes = 30,
    this.isEnabled = false,
    this.sleepGoalMinutes = defaultSleepGoalMinutes,
  });

  static const defaultSleepGoalMinutes = 8 * 60;

  /// When to be in bed to get [goalMinutes] of sleep before [nextAlarm].
  static DateTime bedtimeFor(DateTime nextAlarm, int goalMinutes) =>
      nextAlarm.subtract(Duration(minutes: goalMinutes));

  final TimeOfDay targetBedtime;
  final int windDownMinutes;
  final bool isEnabled;

  /// How long the user wants to sleep each night.
  final int sleepGoalMinutes;

  Map<String, dynamic> toJson() => {
    'bedtimeHour': targetBedtime.hour,
    'bedtimeMinute': targetBedtime.minute,
    'windDownMinutes': windDownMinutes,
    'isEnabled': isEnabled,
    'sleepGoalMinutes': sleepGoalMinutes,
  };

  factory BedtimeSchedule.fromJson(Map<String, dynamic> json) => BedtimeSchedule(
    targetBedtime: TimeOfDay(
      hour: json['bedtimeHour'] as int? ?? 22,
      minute: json['bedtimeMinute'] as int? ?? 30,
    ),
    windDownMinutes: json['windDownMinutes'] as int? ?? 30,
    isEnabled: json['isEnabled'] as bool? ?? false,
    sleepGoalMinutes: json['sleepGoalMinutes'] as int? ?? defaultSleepGoalMinutes,
  );

  BedtimeSchedule copyWith({
    TimeOfDay? targetBedtime,
    int? windDownMinutes,
    bool? isEnabled,
    int? sleepGoalMinutes,
  }) {
    return BedtimeSchedule(
      targetBedtime: targetBedtime ?? this.targetBedtime,
      windDownMinutes: windDownMinutes ?? this.windDownMinutes,
      isEnabled: isEnabled ?? this.isEnabled,
      sleepGoalMinutes: sleepGoalMinutes ?? this.sleepGoalMinutes,
    );
  }
}
