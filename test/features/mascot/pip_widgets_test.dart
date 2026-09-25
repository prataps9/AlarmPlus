import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_line.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/screens/wardrobe_screen.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_says.dart';
import 'package:alarm_plus/features/premium/screens/paywall_screen.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PremiumService.isPro.value = false;
  });

  testWidgets('Pip paints every mood and outfit without throwing',
      (tester) async {
    for (final outfit in MascotOutfit.values) {
      await tester.pumpWidget(_app(Wrap(children: [
        for (final mood in MascotMood.values)
          PipMascot(mood: mood, outfit: outfit, size: 60),
      ])));
      // Run through entrance moves and a full idle loop.
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 2400));
    }
    expect(find.byType(PipMascot), findsNWidgets(MascotMood.values.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching mood and tapping Pip plays without errors',
      (tester) async {
    var taps = 0;
    Widget build(MascotMood mood) => _app(Center(
          child: PipMascot(mood: mood, onTap: () => taps++),
        ));

    await tester.pumpWidget(build(MascotMood.idle));
    await tester.pumpWidget(build(MascotMood.cheering));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byType(PipMascot));
    await tester.pump(const Duration(milliseconds: 800));

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduce-motion freezes Pip on a still pose', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: _app(const PipMascot(mood: MascotMood.cheering)),
    ));
    // Nothing is scheduled, so the tree settles immediately.
    await tester.pumpAndSettle();
    expect(find.byType(PipMascot), findsOneWidget);
  });

  testWidgets('PipSays shows the line text', (tester) async {
    await tester.pumpWidget(_app(const PipSays(
      line: MascotLine(MascotMood.happy, 'All set. See you at 07:00 AM!'),
    )));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('All set. See you at 07:00 AM!'), findsOneWidget);
  });

  testWidgets('paywall lists every benefit and flips to the Pro state',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: PaywallScreen(highlight: PremiumFeature.sleepCoachPro),
    ));
    await tester.pump(const Duration(seconds: 1));

    for (final b in PremiumService.benefits) {
      expect(find.text(b.title), findsOneWidget);
    }
    expect(find.textContaining('Unlock Pro for'), findsOneWidget);

    PremiumService.isPro.value = true;
    await tester.pump();
    // flutter_animate schedules a zero-length start timer in initState;
    // this second pump lets it run.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text("You're Pro!"), findsOneWidget);
  });

  testWidgets('wardrobe locks premium outfits for free users',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: WardrobeScreen()));
    await tester.pump(const Duration(milliseconds: 600));

    final premiumCount = MascotOutfit.values.where((o) => o.isPremium).length;
    expect(find.text('PRO'), findsNWidgets(premiumCount));

    PremiumService.isPro.value = true;
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('PRO'), findsNothing);
  });
}
