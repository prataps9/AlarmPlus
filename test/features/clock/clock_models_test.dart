import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:alarm_plus/features/clock/models/clock_models.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('CityTime', () {
    final tokyo = WorldCity.byName('Tokyo')!;
    final newYork = WorldCity.byName('New York')!;

    test('wall time and offset from an IST phone', () {
      // 2026-09-25 10:00 UTC = 15:30 IST = 19:00 Tokyo.
      final t = CityTime.of(tokyo, DateTime.utc(2026, 9, 25, 10), const Duration(hours: 5, minutes: 30));
      expect(t.wallTime.hour, 19);
      expect(t.wallTime.minute, 0);
      expect(t.offsetFromLocal, const Duration(hours: 3, minutes: 30));
      expect(t.dayLabel, 'Today');
    });

    test('day label crosses midnight both ways', () {
      // 20:00 UTC: IST is 01:30 next day; New York (EDT) is still 16:00.
      final ny = CityTime.of(newYork, DateTime.utc(2026, 9, 25, 20), const Duration(hours: 5, minutes: 30));
      expect(ny.dayLabel, 'Yesterday');
      final tk = CityTime.of(tokyo, DateTime.utc(2026, 9, 25, 16), Duration.zero);
      expect(tk.dayLabel, 'Tomorrow'); // 01:00 in Tokyo
    });

    test('follows DST: New York is UTC-4 in September, UTC-5 in January', () {
      expect(CityTime.of(newYork, DateTime.utc(2026, 9, 1, 12), Duration.zero).offsetFromLocal,
          const Duration(hours: -4));
      expect(CityTime.of(newYork, DateTime.utc(2026, 1, 15, 12), Duration.zero).offsetFromLocal,
          const Duration(hours: -5));
    });

    test('every picker city resolves to a real zone', () {
      for (final c in WorldCity.all) {
        expect(() => CityTime.of(c, DateTime.utc(2026), Duration.zero), returnsNormally, reason: c.name);
      }
    });
  });

  group('StopwatchState', () {
    final t0 = DateTime(2026, 9, 25, 8);

    test('accumulates across pause and resume', () {
      var s = StopwatchState.reset.start(t0);
      s = s.pause(t0.add(const Duration(seconds: 10)));
      expect(s.elapsed(t0.add(const Duration(hours: 1))), const Duration(seconds: 10));
      s = s.start(t0.add(const Duration(seconds: 20)));
      expect(s.elapsed(t0.add(const Duration(seconds: 25))), const Duration(seconds: 15));
    });

    test('lap splits are the time between presses', () {
      var s = StopwatchState.reset.start(t0);
      s = s.lap(t0.add(const Duration(seconds: 30)));
      s = s.lap(t0.add(const Duration(seconds: 75)));
      expect(s.lapSplits, [const Duration(seconds: 30), const Duration(seconds: 45)]);
    });

    test('survives a JSON round-trip while running (app killed)', () {
      final s = StopwatchState.reset.start(t0).lap(t0.add(const Duration(seconds: 5)));
      final back = StopwatchState.fromJson(s.toJson());
      expect(back.isRunning, isTrue);
      expect(back.elapsed(t0.add(const Duration(minutes: 1))), const Duration(minutes: 1));
      expect(back.laps, s.laps);
      expect(StopwatchState.fromJson('garbage').isPristine, isTrue);
    });
  });

  group('CountdownState', () {
    final t0 = DateTime(2026, 9, 25, 8);

    test('counts down, pauses, resumes and finishes', () {
      var c = CountdownState.startNew(const Duration(minutes: 5), t0);
      expect(c.remaining(t0.add(const Duration(minutes: 2))), const Duration(minutes: 3));
      c = c.pause(t0.add(const Duration(minutes: 2)));
      expect(c.remaining(t0.add(const Duration(hours: 1))), const Duration(minutes: 3));
      c = c.resume(t0.add(const Duration(minutes: 10)));
      expect(c.isDone(t0.add(const Duration(minutes: 12, seconds: 59))), isFalse);
      expect(c.isDone(t0.add(const Duration(minutes: 13))), isTrue);
      expect(c.remaining(t0.add(const Duration(minutes: 20))), Duration.zero);
    });

    test('+1:00 extends both the end and the total', () {
      final c = CountdownState.startNew(const Duration(minutes: 1), t0)
          .extend(const Duration(minutes: 1), t0);
      expect(c.total, const Duration(minutes: 2));
      expect(c.fraction(t0), 1.0);
    });

    test('JSON round-trip', () {
      final c = CountdownState.startNew(const Duration(minutes: 3), t0);
      final back = CountdownState.fromJson(c.toJson())!;
      expect(back.endsAt, c.endsAt);
      expect(CountdownState.fromJson(null), isNull);
    });
  });

  group('TimerInput keypad', () {
    TimerInput typed(String digits) {
      var t = const TimerInput();
      for (final d in digits.split('')) {
        t = t.type(int.parse(d));
      }
      return t;
    }

    test('digits shift in from the right', () {
      expect(typed('130').duration, const Duration(minutes: 1, seconds: 30));
      expect(typed('1300').duration, const Duration(minutes: 13));
      expect(typed('10000').duration, const Duration(hours: 1));
    });

    test('ignores leading zeros and caps at six digits', () {
      expect(typed('005').duration, const Duration(seconds: 5));
      expect(typed('1234567').digits, '123456');
    });

    test('backspace and overflow carry', () {
      expect(typed('130').backspace().duration, const Duration(seconds: 13));
      expect(typed('90').duration, const Duration(seconds: 90));
    });
  });

  group('TimeFormat', () {
    test('alarmIn reads like a clock app', () {
      expect(TimeFormat.alarmIn(null), 'No alarms set');
      expect(TimeFormat.alarmIn(const Duration(hours: 7, minutes: 20)), 'Alarm in 7 hr 20 min');
      expect(TimeFormat.alarmIn(const Duration(seconds: 10)), 'Alarm in 1 min');
      expect(TimeFormat.alarmIn(const Duration(days: 2, hours: 3)), 'Alarm in 2 days 3 hr');
    });

    test('stopwatch readout', () {
      expect(TimeFormat.stopwatch(const Duration(minutes: 1, seconds: 2, milliseconds: 345)), '01:02.34');
      expect(TimeFormat.stopwatch(const Duration(hours: 1, minutes: 2, seconds: 3), centis: false), '1:02:03');
    });

    test('city offset', () {
      expect(TimeFormat.offsetFromLocal(Duration.zero), 'Same time');
      expect(TimeFormat.offsetFromLocal(const Duration(hours: 5, minutes: 30)), '+5 hr 30 min');
      expect(TimeFormat.offsetFromLocal(const Duration(hours: -3)), '−3 hr');
    });
  });
}
