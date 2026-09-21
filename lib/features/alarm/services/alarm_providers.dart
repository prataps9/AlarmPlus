import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/shared/models/vibration_pattern_type.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/shared/models/day_type_profile.dart';

/// Provider for the current tab index
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

/// Provider for alarms map state
class AlarmsNotifier extends StateNotifier<Future<Map<String, AlarmModel>>> {
  AlarmsNotifier() : super(_loadInitialAlarms());

  static Future<Map<String, AlarmModel>> _loadInitialAlarms() async {
    final alarms = AlarmService.getAllAlarms();
    final map = <String, AlarmModel>{};
    for (final alarm in alarms) {
      map[alarm.id] = alarm;
    }

    if (map.isEmpty) {
      await _createDefaultAlarms(map);
    }

    return map;
  }

  static Future<void> _createDefaultAlarms(Map<String, AlarmModel> map) async {
    final defaults = [
      AlarmService.createAlarm(
        time: const TimeOfDay(hour: 6, minute: 30),
        label: 'Work Morning',
        repeatDays: const [1, 2, 3, 4, 5],
        isEnabled: true,
        tag: 'Steady wake',
      ),
      AlarmService.createAlarm(
        time: const TimeOfDay(hour: 7, minute: 15),
        label: 'Gentle Wake',
        repeatDays: const [1, 2, 3, 4, 5, 6, 7],
        isEnabled: true,
        tag: 'Gentle wake',
      ),
    ];

    for (final alarm in defaults) {
      await AlarmService.saveAlarm(alarm);
      map[alarm.id] = alarm;
      if (alarm.isEnabled) {
        await AlarmService.scheduleAlarm(alarm);
      }
    }
  }

  /// Save alarm and update local map
  Future<void> saveAlarm(AlarmModel alarm) async {
    try {
      await AlarmService.saveAlarm(alarm);
      final map = await state;
      map[alarm.id] = alarm;
      if (alarm.isEnabled) {
        await AlarmService.scheduleAlarm(alarm);
      }
      state = Future.value(Map.from(map));
    } catch (e) {
      rethrow;
    }
  }

  /// Save an edit to an existing alarm.
  ///
  /// [saveAlarm] only ever schedules, so using it for an edit that switches
  /// the alarm off would leave the previous schedule live and still firing.
  /// This cancels in that case.
  Future<void> updateAlarm(AlarmModel alarm) async {
    await AlarmService.saveAlarm(alarm);
    final map = await state;
    map[alarm.id] = alarm;
    if (alarm.isEnabled) {
      // scheduleAlarm clears the previous schedule for this id first.
      await AlarmService.scheduleAlarm(alarm);
    } else {
      await AlarmService.cancelAlarm(alarm.id);
    }
    state = Future.value(Map.from(map));
  }

  /// Add a new alarm
  Future<void> addAlarm({
    required TimeOfDay time,
    required String label,
    required List<int> repeatDays,
    required bool isEnabled,
    String tag = '',
    String sound = 'default',
    String personality = 'gentle',
    bool gentleWake = false,
    int gentleWakeDurationSeconds = 60,
    ChallengeType? challengeType,
    String? voiceMemoPath,
    int stepGoal = 20,
    int squatReps = 10,
    int snoozeMinutes = 5,
    int maxSnoozes = 0,
    double alarmVolume = 1.0,
    VibrationPatternType vibrationPattern = VibrationPatternType.standard,
    String? savedQrCode,
    bool questMode = false,
    List<ChallengeType>? questSteps,
    bool wakeUpCheckEnabled = false,
    int wakeUpCheckMinutes = 10,
    bool hardcoreMode = false,
    bool sunriseWake = false,
    DayTypeProfile? profile,
  }) async {
    final alarm = AlarmService.createAlarm(
      time: time,
      label: label,
      repeatDays: repeatDays,
      isEnabled: isEnabled,
      tag: tag,
      sound: sound,
      personality: personality,
      gentleWake: gentleWake,
      gentleWakeDurationSeconds: gentleWakeDurationSeconds,
      challengeType: challengeType,
      voiceMemoPath: voiceMemoPath,
      stepGoal: stepGoal,
      squatReps: squatReps,
      snoozeMinutes: snoozeMinutes,
      maxSnoozes: maxSnoozes,
      alarmVolume: alarmVolume,
      vibrationPattern: vibrationPattern,
      savedQrCode: savedQrCode,
      questMode: questMode,
      questSteps: questSteps,
      wakeUpCheckEnabled: wakeUpCheckEnabled,
      wakeUpCheckMinutes: wakeUpCheckMinutes,
      hardcoreMode: hardcoreMode,
      sunriseWake: sunriseWake,
      profile: profile,
    );
    await saveAlarm(alarm);
  }

  /// Skips the next occurrence, or restores it if already skipped.
  Future<void> toggleSkipNext(String id) async {
    final map = await state;
    if (!map.containsKey(id)) return;

    final updated = await AlarmService.toggleSkipNext(id);
    if (updated == null) return;

    map[id] = updated;
    state = Future.value(Map.from(map));
  }

  Future<void> toggleAlarm(String id, bool on) async {
    final map = await state;
    final alarm = map[id];
    if (alarm == null) return;

    final updated = alarm.copyWith(isEnabled: on);
    await AlarmService.toggleAlarm(id, on);
    map[id] = updated;
    state = Future.value(Map.from(map));
  }

  /// Cancel alarm and remove it
  Future<void> cancelAlarm(String id) async {
    await AlarmService.deleteAlarm(id);
    final map = await state;
    map.remove(id);
    state = Future.value(Map.from(map));
  }

  /// Stop alarm
  Future<void> stopAlarm(String id) async {
    final map = await state;
    final alarm = map[id];
    if (alarm == null) return;

    await AlarmService.cancelAlarm(id);

    if (alarm.repeatDays.isNotEmpty) {
      await AlarmService.scheduleAlarm(alarm);
    } else {
      final updated = alarm.copyWith(isEnabled: false);
      map[id] = updated;
      await AlarmService.saveAlarm(updated);
    }
    state = Future.value(Map.from(map));
  }
}

final alarmsMapProvider =
    StateNotifierProvider<AlarmsNotifier, Future<Map<String, AlarmModel>>>(
      (ref) => AlarmsNotifier(),
    );

/// Provider for sorted alarms list (UI use)
final alarmsListProvider = FutureProvider<List<AlarmModel>>((ref) async {
  final map = await ref.watch(alarmsMapProvider);
  final sorted = map.values.toList();
  sorted.sort((a, b) {
    final aMinutes = (a.time.hour * 60) + a.time.minute;
    final bMinutes = (b.time.hour * 60) + b.time.minute;
    return aMinutes.compareTo(bMinutes);
  });
  return sorted;
});

/// One profile's worth of alarms, for the grouped list.
class AlarmGroup {
  const AlarmGroup({required this.profile, required this.alarms});

  /// Null for alarms that belong to no routine.
  final DayTypeProfile? profile;
  final List<AlarmModel> alarms;

  String get label => profile?.label ?? 'Other';

  /// True when every alarm in the group is armed.
  bool get allEnabled => alarms.every((a) => a.isEnabled);
}

/// Pure: groups [alarms] by profile in enum order, with the ungrouped ones
/// last. Empty groups are omitted, and the incoming order is preserved
/// within each group.
List<AlarmGroup> groupAlarmsByProfile(List<AlarmModel> alarms) {
  final groups = <AlarmGroup>[];

  for (final profile in DayTypeProfile.values) {
    final matching = alarms.where((a) => a.profile == profile).toList();
    if (matching.isNotEmpty) {
      groups.add(AlarmGroup(profile: profile, alarms: matching));
    }
  }

  final ungrouped = alarms.where((a) => a.profile == null).toList();
  if (ungrouped.isNotEmpty) {
    groups.add(AlarmGroup(profile: null, alarms: ungrouped));
  }

  return groups;
}

/// Provider for vibration setting
final vibrationEnabledProvider = StateProvider<bool>((ref) => true);

/// Provider for theme setting
final themeDarkProvider = StateProvider<bool>((ref) => false);
