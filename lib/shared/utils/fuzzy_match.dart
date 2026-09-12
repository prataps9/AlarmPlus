/// Text comparison tolerant of speech-recognition slips.
///
/// Recognisers mishear words, drop articles and add punctuation, so requiring
/// an exact transcript would leave people stuck shouting at a ringing phone.
class FuzzyMatch {
  const FuzzyMatch._();

  /// Lowercases, strips punctuation and collapses whitespace.
  static String normalize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r"[^a-z0-9\s']"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Fraction of [reference]'s words that appear in [spoken], 0..1.
  static double tokenOverlap(String reference, String spoken) {
    final refTokens = normalize(reference).split(' ').where((t) => t.isNotEmpty);
    if (refTokens.isEmpty) return 0;

    final saidTokens = normalize(spoken).split(' ').toSet();
    final hits = refTokens.where(saidTokens.contains).length;
    return hits / refTokens.length;
  }

  /// Levenshtein distance between two strings.
  static int editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    var previous = List<int>.generate(b.length + 1, (i) => i);
    var current = List<int>.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        current[j + 1] = [
          current[j] + 1, // insertion
          previous[j + 1] + 1, // deletion
          previous[j] + cost, // substitution
        ].reduce((x, y) => x < y ? x : y);
      }
      final swap = previous;
      previous = current;
      current = swap;
    }

    return previous[b.length];
  }

  /// Edit-distance similarity, 0..1.
  static double similarity(String a, String b) {
    final na = normalize(a);
    final nb = normalize(b);
    if (na.isEmpty && nb.isEmpty) return 1;

    final longest = na.length > nb.length ? na.length : nb.length;
    if (longest == 0) return 1;
    return 1 - (editDistance(na, nb) / longest);
  }

  /// Whether [spoken] is a good-enough rendition of [reference].
  ///
  /// Either measure passing is enough: overlap catches a transcript that got
  /// most words but garbled one, similarity catches one that ran words
  /// together.
  static bool isCloseEnough(
    String reference,
    String spoken, {
    double minOverlap = 0.7,
    double minSimilarity = 0.75,
  }) {
    if (normalize(spoken).isEmpty) return false;
    return tokenOverlap(reference, spoken) >= minOverlap ||
        similarity(reference, spoken) >= minSimilarity;
  }
}
