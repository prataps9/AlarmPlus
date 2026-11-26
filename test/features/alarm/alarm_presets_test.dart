import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/models/alarm_presets.dart';

void main() {
  test('presets are valid times with app-numbered days', () {
    for (final p in AlarmPreset.all) {
      expect(p.hour, inInclusiveRange(0, 23));
      expect(p.minute, inInclusiveRange(0, 59));
      expect(p.days, isNotEmpty);
      expect(p.days.every((d) => d >= 1 && d <= 7), isTrue);
    }
    expect(AlarmPreset.all.first.days, {1, 2, 3, 4, 5});
    expect(AlarmPreset.all[1].days, {6, 7});
  });

  group('turn all off/on', () {
    final alarms = [
      (id: 'a', enabled: true, system: false),
      (id: 'b', enabled: false, system: false),
      (id: 'c', enabled: true, system: true),
    ];

    test('off changes only the user alarms that are on', () {
      expect(idsToSwitch(alarms, on: false), ['a']);
    });

    test('on changes only the user alarms that are off', () {
      expect(idsToSwitch(alarms, on: true), ['b']);
    });

    test('system alarms are never touched', () {
      expect(idsToSwitch([(id: 'c', enabled: false, system: true)], on: true),
          isEmpty);
    });
  });
}
