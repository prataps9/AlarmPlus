import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/shared/utils/fuzzy_match.dart';

void main() {
  group('normalize', () {
    test('lowercases, strips punctuation and collapses whitespace', () {
      expect(
        FuzzyMatch.normalize('  The Quick,   BROWN fox!  '),
        'the quick brown fox',
      );
    });

    test('keeps apostrophes so contractions survive', () {
      expect(FuzzyMatch.normalize("Don't stop"), "don't stop");
    });
  });

  group('isCloseEnough', () {
    const sentence = 'the early bird catches the worm';

    test('accepts an exact match', () {
      expect(FuzzyMatch.isCloseEnough(sentence, sentence), isTrue);
    });

    test('accepts differing case and punctuation', () {
      expect(
        FuzzyMatch.isCloseEnough(sentence, 'The early bird catches the worm.'),
        isTrue,
      );
    });

    test('accepts one misheard word', () {
      expect(
        FuzzyMatch.isCloseEnough(sentence, 'the early bird catches the word'),
        isTrue,
      );
    });

    test('rejects silence', () {
      expect(FuzzyMatch.isCloseEnough(sentence, ''), isFalse);
      expect(FuzzyMatch.isCloseEnough(sentence, '   '), isFalse);
    });

    test('rejects an unrelated sentence', () {
      expect(
        FuzzyMatch.isCloseEnough(sentence, 'please turn off the alarm'),
        isFalse,
      );
    });

    test('rejects saying only a couple of the words', () {
      expect(FuzzyMatch.isCloseEnough(sentence, 'the the'), isFalse);
    });
  });

  group('tokenOverlap', () {
    test('is 1 when every reference word is present', () {
      expect(FuzzyMatch.tokenOverlap('one two three', 'three two one'), 1.0);
    });

    test('is 0 with nothing in common', () {
      expect(FuzzyMatch.tokenOverlap('one two', 'nine ten'), 0.0);
    });

    test('is a fraction when partially present', () {
      expect(FuzzyMatch.tokenOverlap('one two three four', 'one two'), 0.5);
    });
  });

  group('editDistance', () {
    test('is 0 for identical strings', () {
      expect(FuzzyMatch.editDistance('kitten', 'kitten'), 0);
    });

    test('matches the classic example', () {
      expect(FuzzyMatch.editDistance('kitten', 'sitting'), 3);
    });

    test('handles empty input on either side', () {
      expect(FuzzyMatch.editDistance('', 'abc'), 3);
      expect(FuzzyMatch.editDistance('abc', ''), 3);
    });
  });
}
