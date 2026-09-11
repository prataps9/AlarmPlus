import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Intentionally minimal: the real app (AlarmPlusApp) initializes Hive,
// SharedPreferences, and several platform channels in main() before it can
// be pumped, none of which are mocked in this test environment. Full
// widget/route testing is deferred until that setup is fake-able. This
// smoke test just confirms the test harness itself is wired up correctly.
void main() {
  testWidgets('test harness renders a basic widget tree', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Alarm+'))),
      ),
    );

    expect(find.text('Alarm+'), findsOneWidget);
  });
}
