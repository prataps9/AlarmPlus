import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/alarm/widgets/reliability_banner.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';
import 'package:alarm_plus/shared/widgets/alarm_card.dart';

AlarmReliabilityStatus _status({bool notif = true, bool exact = true}) =>
    AlarmReliabilityStatus(
      notificationsGranted: notif,
      exactAlarmGranted: exact,
      batteryOptimizationIgnored: true,
    );

void main() {
  group('reliability banner', () {
    test('silent when alarms can ring', () {
      expect(reliabilityProblem(_status()), isNull);
    });

    test('names exactly what is wrong', () {
      expect(reliabilityProblem(_status(notif: false)), contains('Notifications are off'));
      expect(reliabilityProblem(_status(exact: false)), contains('Exact alarms are off'));
      expect(reliabilityProblem(_status(notif: false, exact: false)), contains('Notifications and exact alarms'));
    });
  });

  group('TimeFormat.clock', () {
    test('12-hour: no leading zero, AM/PM, noon and midnight', () {
      expect(TimeFormat.clock(6, 5, use24h: false), (time: '6:05', period: 'AM'));
      expect(TimeFormat.clock(12, 0, use24h: false), (time: '12:00', period: 'PM'));
      expect(TimeFormat.clock(0, 30, use24h: false), (time: '12:30', period: 'AM'));
    });

    test('24-hour: zero-padded, no period', () {
      expect(TimeFormat.clock(6, 5, use24h: true), (time: '06:05', period: null));
      expect(TimeFormat.clockLabel(18, 45, use24h: true), '18:45');
      expect(TimeFormat.clockLabel(18, 45, use24h: false), '6:45 PM');
    });
  });

  group('alarm card follows the phone\'s 24-hour setting', () {
    final alarm = AlarmModel(
      id: 'a',
      time: const TimeOfDay(hour: 18, minute: 5),
      label: '',
      tag: '',
      sound: 'default',
      isEnabled: true,
      repeatDays: const [],
    );

    Future<void> pump(WidgetTester tester, {required bool use24h}) =>
        tester.pumpWidget(MediaQuery(
          data: MediaQueryData(alwaysUse24HourFormat: use24h),
          child: MaterialApp(
            home: Scaffold(body: AlarmCard(alarm: alarm, onToggle: (_) {})),
          ),
        ));

    testWidgets('24-hour', (tester) async {
      await pump(tester, use24h: true);
      expect(find.textContaining('18:05', findRichText: true), findsOneWidget);
      expect(find.textContaining('PM', findRichText: true), findsNothing);
    });

    testWidgets('12-hour', (tester) async {
      await pump(tester, use24h: false);
      expect(find.textContaining('6:05 PM', findRichText: true), findsOneWidget);
    });
  });

  group('Pro verification against the store', () {
    const id = 'alarm_plus_lifetime_premium';

    test('an unreachable store never changes Pro', () {
      expect(PremiumService.verifiedOwnership(queryFailed: true, purchases: const []), isNull);
    });

    test('owned purchase unlocks; refund (absent) locks', () {
      expect(
        PremiumService.verifiedOwnership(
            queryFailed: false, purchases: const [(id: id, status: PurchaseStatus.purchased)]),
        isTrue,
      );
      expect(PremiumService.verifiedOwnership(queryFailed: false, purchases: const []), isFalse);
    });

    test('a pending payment or another product is not Pro', () {
      expect(
        PremiumService.verifiedOwnership(
            queryFailed: false, purchases: const [(id: id, status: PurchaseStatus.pending)]),
        isFalse,
      );
      expect(
        PremiumService.verifiedOwnership(
            queryFailed: false, purchases: const [(id: 'other', status: PurchaseStatus.purchased)]),
        isFalse,
      );
    });
  });

  test('upcoming-alarm notice leads the alarm by 2 hours', () {
    // Settings says "2 hours before"; keep the copy and the constant in step.
    expect(AlarmService.upcomingNoticeLead, const Duration(hours: 2));
  });
}
