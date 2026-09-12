import 'dart:typed_data';

/// A perceptual hash of a camera frame, used to check you're pointing the
/// phone at the same place you registered.
///
/// Deliberately a difference-hash (dHash) over the luminance plane: it encodes
/// *relative* brightness between neighbouring pixels, so it survives the very
/// thing that would otherwise break this feature — the room being a different
/// brightness at 6am than when you set it up. It needs no image-decoding
/// package and runs cheaply on every frame.
///
/// It is explicitly not a security measure: a photograph of the scene will
/// pass. It's here to make you walk to the sink, not to be unforgeable.
class PhotoHash {
  const PhotoHash._();

  /// Sampled grid: 9 wide so 8 horizontal comparisons per row, 8 rows = 64 bits.
  static const _gridWidth = 9;
  static const _gridHeight = 8;

  /// Computes a 64-bit dHash from a luminance (Y) plane.
  ///
  /// [bytes] is the raw plane, [width]/[height] its dimensions, and
  /// [bytesPerRow] its stride, which is often wider than [width].
  static int fromLuminance(
    Uint8List bytes, {
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    if (width <= 0 || height <= 0 || bytes.isEmpty) return 0;

    // Nearest-neighbour subsample to a 9x8 grid.
    final grid = List<int>.filled(_gridWidth * _gridHeight, 0);
    for (var row = 0; row < _gridHeight; row++) {
      final srcY = ((row * height) ~/ _gridHeight).clamp(0, height - 1);
      for (var col = 0; col < _gridWidth; col++) {
        final srcX = ((col * width) ~/ _gridWidth).clamp(0, width - 1);
        final index = srcY * bytesPerRow + srcX;
        grid[row * _gridWidth + col] =
            index >= 0 && index < bytes.length ? bytes[index] : 0;
      }
    }

    var hash = 0;
    var bit = 0;
    for (var row = 0; row < _gridHeight; row++) {
      for (var col = 0; col < _gridWidth - 1; col++) {
        final left = grid[row * _gridWidth + col];
        final right = grid[row * _gridWidth + col + 1];
        if (left > right) hash |= 1 << bit;
        bit++;
      }
    }
    return hash;
  }

  /// Number of differing bits between two hashes, 0..64.
  static int distance(int a, int b) {
    var diff = a ^ b;
    var count = 0;
    while (diff != 0) {
      count += diff & 1;
      diff >>= 1;
    }
    return count;
  }

  /// Closest distance from [hash] to any registered reference.
  static int bestDistance(int hash, List<int> references) {
    if (references.isEmpty) return 64;
    return references
        .map((ref) => distance(hash, ref))
        .reduce((a, b) => a < b ? a : b);
  }

  static String encode(List<int> hashes) =>
      hashes.map((h) => h.toRadixString(16)).join(',');

  static List<int> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    return encoded
        .split(',')
        .map((part) => int.tryParse(part.trim(), radix: 16))
        .whereType<int>()
        .toList();
  }
}
