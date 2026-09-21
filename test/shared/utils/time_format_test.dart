import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/shared/utils/time_format.dart';

void main() {
  group('formatClockTime', () {
    test('24-hour device gets zero-padded 24-hour time and no period', () {
      expect(
        formatClockTime(const TimeOfDay(hour: 19, minute: 30), use24h: true),
        '19:30',
      );
      expect(
        formatClockTime(const TimeOfDay(hour: 7, minute: 5), use24h: true),
        '07:05',
      );
    });

    test('12-hour device keeps the AM/PM form', () {
      expect(
        formatClockTime(const TimeOfDay(hour: 19, minute: 30), use24h: false),
        '7:30 PM',
      );
      expect(
        formatClockTime(const TimeOfDay(hour: 7, minute: 5), use24h: false),
        '7:05 AM',
      );
    });

    test('midnight and noon read correctly in both formats', () {
      const midnight = TimeOfDay(hour: 0, minute: 0);
      const noon = TimeOfDay(hour: 12, minute: 0);

      expect(formatClockTime(midnight, use24h: true), '00:00');
      expect(formatClockTime(midnight, use24h: false), '12:00 AM');
      expect(formatClockTime(noon, use24h: true), '12:00');
      expect(formatClockTime(noon, use24h: false), '12:00 PM');
    });
  });

  group('split display', () {
    test('digits are zero-padded in both formats', () {
      expect(
        clockDigits(const TimeOfDay(hour: 19, minute: 5), use24h: true),
        '19:05',
      );
      expect(
        clockDigits(const TimeOfDay(hour: 19, minute: 5), use24h: false),
        '07:05',
      );
    });

    test('period label is empty on a 24-hour device', () {
      const evening = TimeOfDay(hour: 19, minute: 5);
      const morning = TimeOfDay(hour: 9, minute: 5);

      expect(clockPeriodLabel(evening, use24h: true), isEmpty);
      expect(clockPeriodLabel(evening, use24h: false), 'PM');
      expect(clockPeriodLabel(morning, use24h: false), 'AM');
    });
  });

  group('uses24HourFormat', () {
    testWidgets('prefers the MediaQuery setting when a context is given',
        (tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(alwaysUse24HourFormat: true),
          child: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(uses24HourFormat(captured), isTrue);
      expect(
        formatClockTime(const TimeOfDay(hour: 19, minute: 30),
            context: captured),
        '19:30',
      );
    });
  });
}
