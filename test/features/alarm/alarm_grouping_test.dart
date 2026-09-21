import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/shared/models/day_type_profile.dart';

AlarmModel _alarm(String id, {DayTypeProfile? profile, bool isEnabled = true}) {
  return AlarmModel(
    id: id,
    time: const TimeOfDay(hour: 7, minute: 0),
    label: id,
    repeatDays: const [],
    isEnabled: isEnabled,
    tag: '',
    sound: 'default',
    profile: profile,
  );
}

void main() {
  group('groupAlarmsByProfile', () {
    test('returns nothing for an empty list', () {
      expect(groupAlarmsByProfile(const []), isEmpty);
    });

    test('alarms with no profile land in a single trailing group', () {
      final groups = groupAlarmsByProfile([_alarm('a'), _alarm('b')]);

      expect(groups, hasLength(1));
      expect(groups.single.profile, isNull);
      expect(groups.single.label, 'Other');
      expect(groups.single.alarms.map((a) => a.id), ['a', 'b']);
    });

    test('groups follow enum order, with ungrouped last', () {
      final groups = groupAlarmsByProfile([
        _alarm('loose'),
        _alarm('weekend', profile: DayTypeProfile.weekend),
        _alarm('work', profile: DayTypeProfile.workday),
        _alarm('gym', profile: DayTypeProfile.gym),
      ]);

      expect(
        groups.map((g) => g.profile),
        [
          DayTypeProfile.workday,
          DayTypeProfile.gym,
          DayTypeProfile.weekend,
          null,
        ],
      );
    });

    test('empty profiles are omitted entirely', () {
      final groups = groupAlarmsByProfile([
        _alarm('work', profile: DayTypeProfile.workday),
      ]);

      expect(groups, hasLength(1));
      expect(groups.single.profile, DayTypeProfile.workday);
      expect(groups.single.label, 'Workday');
    });

    test('order within a group is preserved', () {
      final groups = groupAlarmsByProfile([
        _alarm('first', profile: DayTypeProfile.gym),
        _alarm('second', profile: DayTypeProfile.gym),
        _alarm('third', profile: DayTypeProfile.gym),
      ]);

      expect(groups.single.alarms.map((a) => a.id), ['first', 'second', 'third']);
    });

    test('every alarm appears exactly once', () {
      final alarms = [
        _alarm('a', profile: DayTypeProfile.workday),
        _alarm('b'),
        _alarm('c', profile: DayTypeProfile.travel),
        _alarm('d', profile: DayTypeProfile.workday),
      ];

      final flattened =
          groupAlarmsByProfile(alarms).expand((g) => g.alarms).toList();

      expect(flattened, hasLength(alarms.length));
      expect(flattened.map((a) => a.id).toSet(), {'a', 'b', 'c', 'd'});
    });
  });

  group('AlarmGroup.allEnabled', () {
    test('is true only when every alarm in the group is armed', () {
      const profile = DayTypeProfile.workday;

      expect(
        groupAlarmsByProfile([
          _alarm('a', profile: profile),
          _alarm('b', profile: profile),
        ]).single.allEnabled,
        isTrue,
      );

      expect(
        groupAlarmsByProfile([
          _alarm('a', profile: profile),
          _alarm('b', profile: profile, isEnabled: false),
        ]).single.allEnabled,
        isFalse,
      );
    });
  });
}
