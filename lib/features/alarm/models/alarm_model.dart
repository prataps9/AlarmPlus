import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/shared/models/vibration_pattern_type.dart';

class AlarmModel {
  AlarmModel({
    required this.id,
    required this.time,
    required this.label,
    required this.repeatDays,
    required this.isEnabled,
    required this.tag,
    required this.sound,
    this.personality = 'gentle',
    this.gentleWake = false,
    this.gentleWakeDurationSeconds = 60,
    this.challengeType,
    this.voiceMemoPath,
    this.stepGoal = 20,
    this.squatReps = 10,
    this.photoProofHashes,
    this.savedQrCode,
    this.questMode = false,
    this.questSteps,
    this.wakeUpCheckEnabled = false,
    this.wakeUpCheckMinutes = 10,
    this.hardcoreMode = false,
    this.snoozeMinutes = 5,
    this.maxSnoozes = 0,
    this.alarmVolume = 1.0,
    this.vibrationPattern = VibrationPatternType.standard,
  });

  final String id;
  final TimeOfDay time;
  final String label;
  final List<int> repeatDays;
  final bool isEnabled;
  final String tag;
  final String sound;
  final String personality;
  final bool gentleWake;
  final int gentleWakeDurationSeconds;
  final ChallengeType? challengeType;
  final String? voiceMemoPath;
  final int stepGoal;

  /// Target repetitions for the squat challenge.
  final int squatReps;

  /// Comma-joined hex dHashes of the registered photo-proof scene.
  final String? photoProofHashes;
  final String? savedQrCode;
  final bool questMode;
  final List<ChallengeType>? questSteps;
  final bool wakeUpCheckEnabled;
  final int wakeUpCheckMinutes;
  final bool hardcoreMode;

  /// Minutes added when this alarm is snoozed.
  final int snoozeMinutes;

  /// Maximum number of times this alarm may be snoozed per ring; 0 = unlimited.
  final int maxSnoozes;

  /// Ring volume ceiling, 0.0-1.0. Applied directly at ring start, and as the
  /// ceiling of the gentle-wake ramp when that's enabled.
  final double alarmVolume;

  final VibrationPatternType vibrationPattern;

  String get timeLabel {
    final now = DateTime.now();
    final date = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    return DateFormat('hh:mm').format(date);
  }

  String get periodLabel {
    return time.hour >= 12 ? 'PM' : 'AM';
  }

  String get repeatLabel {
    if (repeatDays.length == 7) {
      return 'Daily';
    }
    const weekdays = {1, 2, 3, 4, 5};
    const weekends = {6, 7};
    final days = repeatDays.toSet();

    // Note: Dart's Set.== is identity-based, not content-based, so this
    // must compare via length + containsAll rather than `days == weekdays`.
    if (days.length == weekdays.length && days.containsAll(weekdays)) {
      return 'Weekdays';
    }
    if (days.length == weekends.length && days.containsAll(weekends)) {
      return 'Weekends';
    }
    return 'Custom';
  }

  DateTime nextDateTimeFrom(DateTime from) {
    var candidate = DateTime(
      from.year,
      from.month,
      from.day,
      time.hour,
      time.minute,
    );

    if (repeatDays.isEmpty) {
      if (candidate.isBefore(from)) {
        candidate = candidate.add(const Duration(days: 1));
      }
      return candidate;
    }

    while (true) {
      final weekday = candidate.weekday;
      final validDay = repeatDays.contains(weekday);
      if (validDay && !candidate.isBefore(from)) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'label': label,
      'repeatDays': repeatDays,
      'isEnabled': isEnabled,
      'tag': tag,
      'sound': sound,
      'personality': personality,
      'gentleWake': gentleWake,
      'gentleWakeDurationSeconds': gentleWakeDurationSeconds,
      'challengeType': challengeType?.name,
      'voiceMemoPath': voiceMemoPath,
      'stepGoal': stepGoal,
      'squatReps': squatReps,
      'photoProofHashes': photoProofHashes,
      'savedQrCode': savedQrCode,
      'questMode': questMode,
      'questSteps': questSteps?.map((e) => e.name).toList(),
      'wakeUpCheckEnabled': wakeUpCheckEnabled,
      'wakeUpCheckMinutes': wakeUpCheckMinutes,
      'hardcoreMode': hardcoreMode,
      'snoozeMinutes': snoozeMinutes,
      'maxSnoozes': maxSnoozes,
      'alarmVolume': alarmVolume,
      'vibrationPattern': vibrationPattern.name,
    };
  }

  factory AlarmModel.fromMap(Map<dynamic, dynamic> map) {
    final rawDays = (map['repeatDays'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) {
          if (item is int) return item;
          if (item is String) return int.tryParse(item) ?? 0;
          return 0;
        })
        .where((day) => day > 0)
        .toList();

    final id = map['id'] as String?;
    final hour = map['hour'] as int?;
    final minute = map['minute'] as int?;

    if (id == null || hour == null || minute == null) {
      throw FormatException('Missing required alarm fields: id=$id, hour=$hour, minute=$minute');
    }

    final challengeTypeStr = map['challengeType'] as String?;
    ChallengeType? challengeType;
    if (challengeTypeStr != null) {
      challengeType = ChallengeType.values.where((e) => e.name == challengeTypeStr).firstOrNull;
    }

    return AlarmModel(
      id: id,
      time: TimeOfDay(hour: hour, minute: minute),
      label: (map['label'] as String?) ?? '',
      repeatDays: rawDays,
      isEnabled: (map['isEnabled'] as bool?) ?? true,
      tag: (map['tag'] as String?) ?? (map['aiTag'] as String?) ?? 'Steady wake',
      sound: (map['sound'] as String?) ?? 'default',
      personality: (map['personality'] as String?) ?? 'gentle',
      gentleWake: (map['gentleWake'] as bool?) ?? false,
      gentleWakeDurationSeconds: (map['gentleWakeDurationSeconds'] as int?) ?? 60,
      challengeType: challengeType,
      voiceMemoPath: map['voiceMemoPath'] as String?,
      stepGoal: (map['stepGoal'] as int?) ?? 20,
      squatReps: (map['squatReps'] as int?) ?? 10,
      photoProofHashes: map['photoProofHashes'] as String?,
      savedQrCode: map['savedQrCode'] as String?,
      questMode: (map['questMode'] as bool?) ?? false,
      questSteps: (map['questSteps'] as List<dynamic>?)
          ?.map((e) => ChallengeType.values
              .where((v) => v.name == e.toString())
              .firstOrNull)
          .whereType<ChallengeType>()
          .toList(),
      wakeUpCheckEnabled: (map['wakeUpCheckEnabled'] as bool?) ?? false,
      wakeUpCheckMinutes: (map['wakeUpCheckMinutes'] as int?) ?? 10,
      hardcoreMode: (map['hardcoreMode'] as bool?) ?? false,
      snoozeMinutes: (map['snoozeMinutes'] as int?) ?? 5,
      maxSnoozes: (map['maxSnoozes'] as int?) ?? 0,
      alarmVolume: (map['alarmVolume'] as num?)?.toDouble() ?? 1.0,
      vibrationPattern: VibrationPatternType.values
              .where((v) => v.name == map['vibrationPattern'])
              .firstOrNull ??
          VibrationPatternType.standard,
    );
  }

  AlarmModel copyWith({
    String? id,
    TimeOfDay? time,
    String? label,
    List<int>? repeatDays,
    bool? isEnabled,
    String? tag,
    String? sound,
    String? personality,
    bool? gentleWake,
    int? gentleWakeDurationSeconds,
    Object? challengeType = _sentinel,
    Object? voiceMemoPath = _sentinel,
    int? stepGoal,
    int? squatReps,
    Object? photoProofHashes = _sentinel,
    Object? savedQrCode = _sentinel,
    bool? questMode,
    Object? questSteps = _sentinel,
    bool? wakeUpCheckEnabled,
    int? wakeUpCheckMinutes,
    bool? hardcoreMode,
    int? snoozeMinutes,
    int? maxSnoozes,
    double? alarmVolume,
    VibrationPatternType? vibrationPattern,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      time: time ?? this.time,
      label: label ?? this.label,
      repeatDays: repeatDays ?? this.repeatDays,
      isEnabled: isEnabled ?? this.isEnabled,
      tag: tag ?? this.tag,
      sound: sound ?? this.sound,
      personality: personality ?? this.personality,
      gentleWake: gentleWake ?? this.gentleWake,
      gentleWakeDurationSeconds: gentleWakeDurationSeconds ?? this.gentleWakeDurationSeconds,
      challengeType: challengeType == _sentinel ? this.challengeType : challengeType as ChallengeType?,
      voiceMemoPath: voiceMemoPath == _sentinel ? this.voiceMemoPath : voiceMemoPath as String?,
      stepGoal: stepGoal ?? this.stepGoal,
      squatReps: squatReps ?? this.squatReps,
      photoProofHashes: identical(photoProofHashes, _sentinel)
          ? this.photoProofHashes
          : photoProofHashes as String?,
      savedQrCode: savedQrCode == _sentinel ? this.savedQrCode : savedQrCode as String?,
      questMode: questMode ?? this.questMode,
      questSteps: questSteps == _sentinel ? this.questSteps : questSteps as List<ChallengeType>?,
      wakeUpCheckEnabled: wakeUpCheckEnabled ?? this.wakeUpCheckEnabled,
      wakeUpCheckMinutes: wakeUpCheckMinutes ?? this.wakeUpCheckMinutes,
      hardcoreMode: hardcoreMode ?? this.hardcoreMode,
      snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
      maxSnoozes: maxSnoozes ?? this.maxSnoozes,
      alarmVolume: alarmVolume ?? this.alarmVolume,
      vibrationPattern: vibrationPattern ?? this.vibrationPattern,
    );
  }
}

const Object _sentinel = Object();
