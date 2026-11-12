import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/features/alarm/challenges/morning_quiz.dart';
import 'package:alarm_plus/features/alarm/challenges/recall_round.dart';
import 'package:alarm_plus/features/alarm/challenges/wake_brain_challenges.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.build(Brightness.light, useGoogleFonts: false),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

void main() {
  final now = DateTime(2026, 11, 12, 6, 30);

  testWidgets('wake-up questions: right answers pass, a wrong one swaps the question',
      (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var passed = false;
    // Same seed as the widget, to know the answers.
    final expected = MorningQuiz.generate(now, const QuizFacts(), Random(7), count: 2);
    await tester.pumpWidget(_host(MorningQuizChallengeWidget(
      now: now,
      count: 2,
      random: Random(7),
      speak: false,
      onPassed: () => passed = true,
    )));
    expect(find.text(expected[0].prompt), findsOneWidget);

    // A wrong answer: still question 1, with a new question.
    final wrong = expected[0].options.firstWhere((o) => o != expected[0].answer);
    await tester.tap(find.text(wrong));
    await tester.pump(const Duration(milliseconds: 950));
    await tester.pumpAndSettle();
    expect(find.text('1/2'), findsOneWidget);
    expect(passed, isFalse);

    // Answer whatever is shown correctly until done.
    for (var i = 0; i < 4 && !passed; i++) {
      final prompt = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .firstWhere((t) => t.endsWith('?'));
      // Rebuild the answer for the shown prompt.
      final answer = _answerFor(prompt, now);
      await tester.tap(find.text(answer));
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();
    }
    expect(passed, isTrue);
  });

  testWidgets('remember & recall: memorise, sum, pick the words', (tester) async {
    tester.view.physicalSize = const Size(412 * 2, 1600 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    var passed = false;
    final rng = Random(4);
    final round = RecallRound.create(Random(4));
    await tester.pumpWidget(_host(RecallChallengeWidget(
      random: rng,
      speak: false,
      onPassed: () => passed = true,
    )));
    for (final w in round.words) {
      expect(find.text(w), findsOneWidget);
    }
    await tester.tap(find.text("I've got them"));
    await tester.pumpAndSettle();

    // The sum.
    final prompt = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .firstWhere((t) => t.endsWith('= ?'));
    final nums = RegExp(r'\d+').allMatches(prompt).map((m) => int.parse(m[0]!)).toList();
    await tester.tap(find.text('${nums[0] + nums[1]}'));
    await tester.pump(const Duration(milliseconds: 750));
    await tester.pumpAndSettle();

    expect(find.text('Which 4 words did you see?'), findsOneWidget);
    for (final w in round.words) {
      await tester.tap(find.text(w));
      await tester.pump();
    }
    await tester.tap(find.text('Check (4/4)'));
    await tester.pump(const Duration(milliseconds: 750));
    expect(passed, isTrue);
  });

  testWidgets('memorise step moves on by itself', (tester) async {
    await tester.pumpWidget(_host(RecallChallengeWidget(
      speak: false,
      memoriseFor: const Duration(seconds: 2),
      onPassed: () {},
    )));
    expect(find.text("I've got them"), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Quick sum first'), findsOneWidget);
  });
}

String _answerFor(String prompt, DateTime now) {
  // Only fact-free questions can appear (no QuizFacts given): weekday,
  // date, month, or a sum.
  const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
  if (prompt == 'What day is it today?') return days[now.weekday - 1];
  if (prompt == "What's today's date?") return '12 November';
  if (prompt == 'Which month is it?') return 'November';
  final n = RegExp(r'\d+').allMatches(prompt).map((m) => int.parse(m[0]!)).toList();
  return '${n[0] + n[1]}';
}
