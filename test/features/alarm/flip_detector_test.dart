import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/features/alarm/services/flip_detector.dart';

void main() {
  final t0 = DateTime(2026, 1, 1, 7);
  DateTime at(int ms) => t0.add(Duration(milliseconds: ms));

  test('fires once after the phone stays face down', () {
    final d = FlipDetector();
    expect(d.add(-9.8, at(0)), isFalse);
    expect(d.add(-9.7, at(500)), isFalse);
    expect(d.add(-9.8, at(950)), isTrue);
    expect(d.add(-9.8, at(1500)), isFalse, reason: 'only once');
  });

  test('a brief tilt does not fire, and face-up resets the hold', () {
    final d = FlipDetector();
    d.add(-9.8, at(0));
    d.add(9.8, at(400)); // picked up again
    expect(d.add(-9.8, at(800)), isFalse);
    expect(d.add(-9.8, at(1600)), isFalse, reason: 'held only 800 ms');
    expect(d.add(-9.8, at(1750)), isTrue);
  });

  test('re-arms after being turned face up', () {
    final d = FlipDetector();
    d.add(-9.8, at(0));
    expect(d.add(-9.8, at(1000)), isTrue);
    d.add(9.8, at(1200));
    d.add(-9.8, at(1300));
    expect(d.add(-9.8, at(2300)), isTrue);
  });

  test('on its side or upright is not face down', () {
    final d = FlipDetector();
    for (var ms = 0; ms < 3000; ms += 100) {
      expect(d.add(0.5, at(ms)), isFalse);
    }
  });

  test('volume button setting parses safely', () {
    expect(VolumeButtons.parse(null), VolumeButtons.snooze);
    expect(VolumeButtons.parse('junk'), VolumeButtons.snooze);
    expect(VolumeButtons.parse('volume'), VolumeButtons.volume);
    expect(AppSettings.silenceAfterChoices.where((m) => m > 0).every((m) => m > 10), isTrue,
        reason: 'every choice comes after the 10-minute guardian alert');
    expect(AppSettings.silenceAfterLabel(0), 'Never');
  });
}
