import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/features/settings/screens/settings_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> open(WidgetTester tester,
      {double width = 412, double scale = 1.0, bool dark = false}) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
    messenger.setMockMethodCallHandler(permissions, (call) async => 1);
    messenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/package_info'),
        (call) async => {
              'appName': 'Alarm+',
              'packageName': 'com.alarmplus.app',
              'version': '1.2.2',
              'buildNumber': '5',
            });
    messenger.setMockMethodCallHandler(NativeControls.channel, (call) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(permissions, null);
      messenger.setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'), null);
      messenger.setMockMethodCallHandler(NativeControls.channel, null);
    });
    tester.view.physicalSize = Size(width * 2, 4200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
        home: MediaQuery(
          data: MediaQueryData(
              size: Size(width, 2100), textScaler: TextScaler.linear(scale)),
          child: const Scaffold(body: SettingsScreen()),
        ),
      ),
    ));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('groups the settings and lists the core ones', (tester) async {
    await open(tester);
    for (final label in ['ALARMS', 'RELIABILITY & SAFETY', 'SLEEP', 'APPEARANCE', 'BACKUP', 'ABOUT']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Live Alarm Countdown'), findsOneWidget);
    expect(find.text('Alarm Health Check'), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('search narrows the list by title or keyword', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'capsule');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Live Alarm Countdown'), findsOneWidget);
    expect(find.text('Sleep Diary'), findsNothing);
    expect(find.text('SLEEP'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('No settings match'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Sleep Diary'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets('fits 320dp with 1.3x text (dark: $dark)', (tester) async {
      await open(tester, width: 320, scale: 1.3, dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Alarm Health Check'), findsOneWidget);
    });
  }
}
