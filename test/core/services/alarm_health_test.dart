import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/alarm_health_service.dart';
import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/features/settings/screens/alarm_health_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final due = DateTime(2026, 10, 28, 7, 0);
  final dueMs = due.millisecondsSinceEpoch;

  group('test alarm outcome', () {
    HealthTestState at(DateTime now, {int? fired}) => AlarmHealthService.evaluate(
        dueMs: dueMs, firedMs: fired, now: now).state;

    test('never run', () {
      expect(AlarmHealthService.evaluate(now: due).state, HealthTestState.none);
    });

    test('waiting until a few minutes past due, then failed', () {
      expect(at(due.subtract(const Duration(seconds: 30))), HealthTestState.waiting);
      expect(at(due.add(const Duration(minutes: 2))), HealthTestState.waiting);
      expect(at(due.add(const Duration(minutes: 4))), HealthTestState.failed);
    });

    test('fired on time passes; fired minutes late is "late"', () {
      final later = due.add(const Duration(hours: 1));
      final onTime = due.add(const Duration(seconds: 8)).millisecondsSinceEpoch;
      final late = due.add(const Duration(minutes: 9)).millisecondsSinceEpoch;
      expect(at(later, fired: onTime), HealthTestState.passed);
      expect(at(later, fired: late), HealthTestState.late);
      expect(
          AlarmHealthService.evaluate(dueMs: dueMs, firedMs: late, now: later)
              .lateBy,
          const Duration(minutes: 9));
    });
  });

  test('advice for the phone makers known to block alarm apps', () {
    for (final maker in ['xiaomi', 'oppo', 'vivo', 'huawei', 'oneplus', 'samsung', 'asus']) {
      expect(AlarmHealthService.makerAdvice(maker), isNotNull, reason: maker);
    }
    expect(AlarmHealthService.makerAdvice('google'), isNull);
    expect(AlarmHealthService.makerAdvice(null), isNull);
  });

  testWidgets('a failed test says so, with the phone maker steps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(NativeControls.channel, (call) async {
      switch (call.method) {
        case 'healthTestResult':
          return {'due': DateTime.now().subtract(const Duration(minutes: 10)).millisecondsSinceEpoch};
        case 'phoneMaker':
          return 'xiaomi';
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(NativeControls.channel, null));
    // Every permission granted, so only the test result is a problem.
    const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
    messenger.setMockMethodCallHandler(permissions, (call) async => 1);
    addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));

    // Tall enough that the test card at the bottom is built.
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: AlarmHealthScreen()));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.textContaining("didn't go off"), findsOneWidget);
    expect(find.textContaining('Xiaomi, Redmi and POCO'), findsOneWidget);
    expect(find.text('Test again'), findsOneWidget);
    expect(find.text('1 thing to fix'), findsOneWidget);
  });

  for (final state in ['waiting', 'late', 'failed']) {
    testWidgets('fits a 320dp phone with 1.3x text ($state)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final now = DateTime.now();
      final result = switch (state) {
        'waiting' => {'due': now.add(const Duration(seconds: 40)).millisecondsSinceEpoch},
        'late' => {
            'due': now.subtract(const Duration(minutes: 20)).millisecondsSinceEpoch,
            'fired': now.subtract(const Duration(minutes: 8)).millisecondsSinceEpoch,
          },
        _ => {'due': now.subtract(const Duration(minutes: 10)).millisecondsSinceEpoch},
      };
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(NativeControls.channel, (call) async {
        if (call.method == 'healthTestResult') return result;
        if (call.method == 'phoneMaker') return 'oppo';
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(NativeControls.channel, null));
      const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
      messenger.setMockMethodCallHandler(permissions, (call) async => 0);
      addTearDown(() => messenger.setMockMethodCallHandler(permissions, null));

      tester.view.physicalSize = const Size(320 * 2.0, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: Brightness.dark),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: AlarmHealthScreen(),
        ),
      ));
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Oppo and Realme'), findsOneWidget);
      // Stop the 5 s re-check timer of the waiting state.
      await tester.pumpWidget(const SizedBox());
    });
  }
}
