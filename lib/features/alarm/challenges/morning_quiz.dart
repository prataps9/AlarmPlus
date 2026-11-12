import 'dart:math';

import 'package:intl/intl.dart';

/// One multiple-choice question; [options] always contains [answer] once.
class QuizQuestion {
  const QuizQuestion(this.prompt, this.options, this.answer, {this.spoken});

  final String prompt;
  final List<String> options;
  final String answer;

  /// What text-to-speech reads (defaults to [prompt]).
  final String? spoken;

  int get answerIndex => options.indexOf(answer);
}

/// What the app knows about this morning, used to ask questions only a
/// person who is actually awake can answer. All optional: a question whose
/// fact is missing is simply not asked.
class QuizFacts {
  const QuizFacts({
    this.alarmHour,
    this.alarmMinute,
    this.alarmLabel,
    this.streak,
    this.yesterdayWake,
    this.use24h = false,
  });

  final int? alarmHour;
  final int? alarmMinute;
  final String? alarmLabel;
  final int? streak;
  final DateTime? yesterdayWake;
  final bool use24h;
}

/// "Wake-up questions": orientation questions about today and this alarm,
/// mixed with a quick sum, so answering needs a mind that is switched on.
/// Pure: [now] and [rng] are passed in, so it is fully testable.
class MorningQuiz {
  MorningQuiz._();

  static const _labels = [
    'Wake up', 'Gym', 'Work', 'School', 'Meds', 'Meeting', 'Walk the dog',
    'Flight', 'Run', 'Study',
  ];

  /// [count] questions, each kind at most once (the sum may repeat).
  static List<QuizQuestion> generate(
    DateTime now,
    QuizFacts facts,
    Random rng, {
    int count = 3,
  }) {
    final makers = <QuizQuestion? Function()>[
      () => _weekday(now, rng),
      () => _date(now, rng),
      () => _month(now, rng),
      () => _alarmTime(facts, rng),
      () => _alarmLabel(facts, rng),
      () => _streak(facts, rng),
      () => _yesterdayWake(facts, rng),
    ]..shuffle(rng);
    final out = <QuizQuestion>[];
    for (final make in makers) {
      if (out.length >= count) break;
      final q = make();
      if (q != null) out.add(q);
      // Every third question is a sum, so it's not only recall.
      if (out.length < count && out.length % 3 == 2) out.add(sum(rng));
    }
    while (out.length < count) {
      out.add(sum(rng));
    }
    return out.take(count).toList();
  }

  /// A single replacement question (after a wrong answer).
  static QuizQuestion one(DateTime now, QuizFacts facts, Random rng) =>
      generate(now, facts, rng, count: 1).first;

  static List<String> _choices(String answer, Iterable<String> pool, Random rng) {
    final others = pool.where((o) => o != answer).toSet().toList()..shuffle(rng);
    return [answer, ...others.take(3)]..shuffle(rng);
  }

  static QuizQuestion _weekday(DateTime now, Random rng) {
    final answer = DateFormat('EEEE').format(now);
    final pool = [
      for (var i = 0; i < 7; i++)
        DateFormat('EEEE').format(now.add(Duration(days: i))),
    ];
    return QuizQuestion('What day is it today?', _choices(answer, pool, rng), answer);
  }

  static QuizQuestion _date(DateTime now, Random rng) {
    String f(DateTime d) => DateFormat('d MMMM').format(d);
    final answer = f(now);
    final pool = [
      for (final delta in [-2, -1, 1, 2, 7, -7]) f(now.add(Duration(days: delta))),
    ];
    return QuizQuestion("What's today's date?", _choices(answer, pool, rng), answer);
  }

  static QuizQuestion _month(DateTime now, Random rng) {
    String f(int m) => DateFormat('MMMM').format(DateTime(2000, m));
    final answer = f(now.month);
    final pool = [for (var m = 1; m <= 12; m++) f(m)];
    return QuizQuestion('Which month is it?', _choices(answer, pool, rng), answer);
  }

  static String _clock(int h, int m, bool use24h) {
    final t = DateTime(2000, 1, 1, h, m);
    return use24h ? DateFormat('HH:mm').format(t) : DateFormat('h:mm a').format(t);
  }

  static QuizQuestion? _alarmTime(QuizFacts f, Random rng) {
    final h = f.alarmHour, m = f.alarmMinute;
    if (h == null || m == null) return null;
    final base = h * 60 + m;
    String at(int mins) {
      final x = (mins % 1440 + 1440) % 1440;
      return _clock(x ~/ 60, x % 60, f.use24h);
    }
    final answer = at(base);
    final pool = [for (final d in [-60, -30, -15, 15, 30, 60, 90]) at(base + d)];
    return QuizQuestion('What time was this alarm set for?',
        _choices(answer, pool, rng), answer);
  }

  static QuizQuestion? _alarmLabel(QuizFacts f, Random rng) {
    final label = f.alarmLabel?.trim();
    if (label == null || label.isEmpty) return null;
    return QuizQuestion("What's this alarm called?",
        _choices(label, _labels, rng), label);
  }

  static QuizQuestion? _streak(QuizFacts f, Random rng) {
    final s = f.streak;
    if (s == null || s < 2) return null;
    final answer = '$s days';
    final pool = [
      for (final d in [-2, -1, 1, 2, 3])
        if (s + d >= 0) '${s + d} days',
    ];
    return QuizQuestion("What's your wake-up streak?",
        _choices(answer, pool, rng), answer);
  }

  static QuizQuestion? _yesterdayWake(QuizFacts f, Random rng) {
    final y = f.yesterdayWake;
    if (y == null) return null;
    // Rounded to 5 minutes: nobody remembers 6:47 exactly.
    final rounded = (y.hour * 60 + y.minute) ~/ 5 * 5;
    String at(int mins) {
      final x = (mins % 1440 + 1440) % 1440;
      return _clock(x ~/ 60, x % 60, f.use24h);
    }
    final answer = 'About ${at(rounded)}';
    final pool = [for (final d in [-90, -45, 45, 90, 120]) 'About ${at(rounded + d)}'];
    return QuizQuestion('When did you get up yesterday?',
        _choices(answer, pool, rng), answer);
  }

  /// A quick two-digit sum with close wrong answers.
  static QuizQuestion sum(Random rng) {
    final a = 11 + rng.nextInt(49), b = 11 + rng.nextInt(49);
    final answer = '${a + b}';
    final pool = [for (final d in [-10, -2, -1, 1, 2, 10]) '${a + b + d}'];
    return QuizQuestion('$a + $b = ?', _choices(answer, pool, rng), answer,
        spoken: '$a plus $b?');
  }
}
