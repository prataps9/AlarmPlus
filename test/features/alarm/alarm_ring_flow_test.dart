import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';

void main() {
  group('canSnoozeAgain', () {
    test('unlimited (maxSnoozes = 0) always allows another snooze', () {
      expect(canSnoozeAgain(used: 0, maxSnoozes: 0), isTrue);
      expect(canSnoozeAgain(used: 50, maxSnoozes: 0), isTrue);
    });

    test('allows snoozing while under the cap', () {
      expect(canSnoozeAgain(used: 0, maxSnoozes: 3), isTrue);
      expect(canSnoozeAgain(used: 2, maxSnoozes: 3), isTrue);
    });

    test('refuses once the cap is reached', () {
      expect(canSnoozeAgain(used: 3, maxSnoozes: 3), isFalse);
    });

    test('refuses if somehow already past the cap', () {
      expect(canSnoozeAgain(used: 4, maxSnoozes: 3), isFalse);
    });

    test('a cap of 1 allows exactly one snooze', () {
      expect(canSnoozeAgain(used: 0, maxSnoozes: 1), isTrue);
      expect(canSnoozeAgain(used: 1, maxSnoozes: 1), isFalse);
    });
  });
}
