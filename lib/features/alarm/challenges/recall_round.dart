import 'dart:math';

/// "Remember & recall": memorise a few words, do a sum, then pick the words
/// out of a larger set. Pure model, so it is testable.
class RecallRound {
  RecallRound._(this.words, this.choices);

  /// Everyday, concrete, easy-to-picture words (no near-duplicates).
  static const pool = [
    'lamp', 'river', 'coffee', 'seven', 'garden', 'pencil', 'window', 'tiger',
    'bread', 'cloud', 'guitar', 'orange', 'bridge', 'candle', 'rocket',
    'pillow', 'mirror', 'forest', 'bottle', 'ladder', 'violin', 'jacket',
    'island', 'kettle', 'button', 'carpet', 'helmet', 'lemon', 'saddle',
    'tunnel', 'wallet', 'zebra', 'anchor', 'basket', 'camera', 'dragon',
    'feather', 'hammer', 'mango', 'planet',
  ];

  /// The words to remember.
  final List<String> words;

  /// [words] plus as many decoys, shuffled.
  final List<String> choices;

  factory RecallRound.create(Random rng, {int size = 4}) {
    final shuffled = [...pool]..shuffle(rng);
    final words = shuffled.take(size).toList();
    final choices = shuffled.take(size * 2).toList()..shuffle(rng);
    return RecallRound._(words, choices);
  }

  /// True when [picked] is exactly the remembered words.
  bool check(Set<String> picked) =>
      picked.length == words.length && picked.containsAll(words);
}
