import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/challenges/color_clash_challenge_widget.dart';
import 'package:alarm_plus/features/alarm/services/challenge_service.dart';
import 'package:alarm_plus/shared/models/challenge_type.dart';

void main() {
  group('ColorClashGame rounds', () {
    test('always offer 4 distinct options including the ink', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = ColorClashGame(random: Random(seed)).round;
        expect(r.options.toSet(), hasLength(4), reason: 'seed $seed');
        expect(r.options, contains(r.ink));
      }
    });

    test('the tempting word is offered whenever it differs from the ink', () {
      for (var seed = 0; seed < 200; seed++) {
        final r = ColorClashGame(random: Random(seed)).round;
        expect(r.options, contains(r.word));
      }
    });

    test('most rounds are real clashes (word != ink)', () {
      var clashes = 0;
      final game = ColorClashGame(random: Random(1), target: 1000);
      for (var i = 0; i < 500; i++) {
        if (game.round.word != game.round.ink) clashes++;
        game.answer(game.round.ink);
      }
      expect(clashes, greaterThan(350));
      expect(clashes, lessThan(500)); // some matches, so "never tap the word" fails
    });
  });

  group('ColorClashGame scoring', () {
    test('the ink colour is the right answer and builds the streak', () {
      final game = ColorClashGame(random: Random(3), target: 3);
      expect(game.answer(game.round.ink), isTrue);
      expect(game.answer(game.round.ink), isTrue);
      expect(game.won, isFalse);
      expect(game.answer(game.round.ink), isTrue);
      expect(game.won, isTrue);
    });

    test('a wrong tap resets the streak and counts a mistake', () {
      final game = ColorClashGame(random: Random(4));
      game.answer(game.round.ink);
      game.answer(game.round.ink);
      final wrong = game.round.options.firstWhere((c) => c != game.round.ink);
      expect(game.answer(wrong), isFalse);
      expect(game.streak, 0);
      expect(game.mistakes, 1);
    });
  });

  test('Color Clash is offered by Random and in quests', () {
    expect(ChallengeService.pickable, contains(ChallengeType.colorClash));
    expect(ChallengeService.questPickable, contains(ChallengeType.colorClash));
    expect(ChallengeService.label(ChallengeType.colorClash), 'Color Clash');
  });

  testWidgets('tapping the ink colour 3 times passes the challenge',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    var passed = false;
    // A twin game with the same seed predicts every round the widget deals.
    final oracle = ColorClashGame(random: Random(42), target: 3);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ColorClashChallengeWidget(
          target: 3,
          random: Random(42),
          onPassed: () => passed = true,
          onFailed: () {},
        ),
      ),
    ));

    // A wrong tap first: it must reset, not fail the challenge.
    final wrong = oracle.round.options.firstWhere((c) => c != oracle.round.ink);
    await tester.tap(find.byKey(ValueKey('clash-${wrong.name}')));
    oracle.answer(wrong);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Oops, streak reset!'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      final ink = oracle.round.ink;
      await tester.tap(find.byKey(ValueKey('clash-${ink.name}')));
      oracle.answer(ink);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 400));
    expect(passed, isTrue);
  });
}
