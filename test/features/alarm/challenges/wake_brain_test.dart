import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/challenges/morning_quiz.dart';
import 'package:alarm_plus/features/alarm/challenges/recall_round.dart';

void main() {
  final now = DateTime(2026, 11, 12, 6, 30); // a Thursday

  group('MorningQuiz', () {
    test('every question has 4 unique choices containing the answer once', () {
      for (var seed = 0; seed < 200; seed++) {
        final qs = MorningQuiz.generate(
          now,
          QuizFacts(
            alarmHour: 6,
            alarmMinute: 30,
            alarmLabel: 'Gym',
            streak: 5,
            yesterdayWake: DateTime(2026, 11, 11, 7, 2),
          ),
          Random(seed),
          count: 5,
        );
        expect(qs, hasLength(5));
        for (final q in qs) {
          expect(q.options.toSet(), hasLength(q.options.length), reason: q.prompt);
          expect(q.options.length, 4, reason: q.prompt);
          expect(q.options.where((o) => o == q.answer), hasLength(1), reason: q.prompt);
          expect(q.answerIndex, greaterThanOrEqualTo(0));
        }
      }
    });

    test('answers are true for the given morning', () {
      final all = <String, String>{};
      for (var seed = 0; seed < 300; seed++) {
        for (final q in MorningQuiz.generate(
            now,
            const QuizFacts(alarmHour: 6, alarmMinute: 30, alarmLabel: 'Gym', streak: 5),
            Random(seed),
            count: 5)) {
          all[q.prompt] = q.answer;
        }
      }
      expect(all['What day is it today?'], 'Thursday');
      expect(all["What's today's date?"], '12 November');
      expect(all['Which month is it?'], 'November');
      expect(all['What time was this alarm set for?'], '6:30 AM');
      expect(all["What's this alarm called?"], 'Gym');
      expect(all["What's your wake-up streak?"], '5 days');
    });

    test('questions without facts are not asked', () {
      for (var seed = 0; seed < 100; seed++) {
        for (final q in MorningQuiz.generate(now, const QuizFacts(), Random(seed), count: 5)) {
          expect(q.prompt, isNot(contains('alarm')));
          expect(q.prompt, isNot(contains('streak')));
          expect(q.prompt, isNot(contains('yesterday')));
        }
      }
    });

    test('24-hour phones get 24-hour times', () {
      final q = MorningQuiz.generate(
              now,
              const QuizFacts(alarmHour: 18, alarmMinute: 5, use24h: true),
              Random(1),
              count: 7)
          .firstWhere((q) => q.prompt.contains('set for'));
      expect(q.answer, '18:05');
    });

    test('sums are correct', () {
      for (var seed = 0; seed < 50; seed++) {
        final q = MorningQuiz.sum(Random(seed));
        final parts = q.prompt.split(RegExp(r'[^0-9]+')).where((s) => s.isNotEmpty).map(int.parse).toList();
        expect(int.parse(q.answer), parts[0] + parts[1]);
      }
    });
  });

  group('RecallRound', () {
    test('words are among the choices, choices are unique and twice as many', () {
      for (var seed = 0; seed < 100; seed++) {
        final r = RecallRound.create(Random(seed));
        expect(r.words, hasLength(4));
        expect(r.choices.toSet(), hasLength(8));
        expect(r.choices.toSet().containsAll(r.words), isTrue);
      }
    });

    test('only exactly the remembered words pass', () {
      final r = RecallRound.create(Random(3));
      expect(r.check(r.words.toSet()), isTrue);
      final decoy = r.choices.firstWhere((c) => !r.words.contains(c));
      expect(r.check({...r.words.take(3), decoy}), isFalse);
      expect(r.check(r.words.take(3).toSet()), isFalse);
    });

    test('pool has no duplicates', () {
      expect(RecallRound.pool.toSet(), hasLength(RecallRound.pool.length));
    });
  });
}
