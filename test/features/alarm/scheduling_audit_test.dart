import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('two alarms in the same minute both stay scheduled', () {
    final seven = DateTime(2026, 10, 23, 7);
    int sec(DateTime d) => d.millisecondsSinceEpoch ~/ 1000;

    test('a free second is used as is', () {
      expect(AlarmService.uniqueSecond(seven, {}), seven);
    });

    test('a taken second moves to the next free one', () {
      // The plugin stops any other alarm due in the same second.
      expect(AlarmService.uniqueSecond(seven, {sec(seven)}),
          seven.add(const Duration(seconds: 1)));
      expect(
          AlarmService.uniqueSecond(seven, {
            sec(seven),
            sec(seven.add(const Duration(seconds: 1))),
          }),
          seven.add(const Duration(seconds: 2)));
    });
  });
}
