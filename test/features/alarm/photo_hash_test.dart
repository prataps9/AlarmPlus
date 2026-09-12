import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/features/alarm/challenges/photo_hash.dart';

/// Builds a synthetic luminance plane from a function of (x, y).
Uint8List _plane(
  int width,
  int height,
  int Function(int x, int y) pixel, {
  int? bytesPerRow,
}) {
  final stride = bytesPerRow ?? width;
  final bytes = Uint8List(stride * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bytes[y * stride + x] = pixel(x, y).clamp(0, 255);
    }
  }
  return bytes;
}

int _hashOf(Uint8List bytes, int w, int h, {int? stride}) =>
    PhotoHash.fromLuminance(
      bytes,
      width: w,
      height: h,
      bytesPerRow: stride ?? w,
    );

void main() {
  group('fromLuminance', () {
    test('identical frames hash identically', () {
      final scene = _plane(64, 48, (x, y) => (x * 3 + y * 5) % 256);

      expect(_hashOf(scene, 64, 48), _hashOf(scene, 64, 48));
    });

    test('different scenes hash differently', () {
      final kitchen = _plane(64, 48, (x, y) => (x * 3 + y * 5) % 256);
      final bathroom = _plane(64, 48, (x, y) => (x * 11 + y * 2) % 256);

      expect(_hashOf(kitchen, 64, 48), isNot(_hashOf(bathroom, 64, 48)));
      expect(
        PhotoHash.distance(_hashOf(kitchen, 64, 48), _hashOf(bathroom, 64, 48)),
        greaterThan(8),
      );
    });

    test('survives a uniform brightness shift', () {
      // This is the whole reason for a gradient hash: the same room is much
      // darker at 6am than when the reference was captured.
      final bright = _plane(64, 48, (x, y) => (x * 3 + y * 5) % 200 + 55);
      final dim = _plane(64, 48, (x, y) => ((x * 3 + y * 5) % 200 + 55) ~/ 3);

      final distance =
          PhotoHash.distance(_hashOf(bright, 64, 48), _hashOf(dim, 64, 48));

      expect(distance, lessThanOrEqualTo(16));
    });

    test('tolerates mild sensor noise', () {
      final rng = Random(7);
      final base = _plane(64, 48, (x, y) => (x * 3 + y * 5) % 256);
      final noisy = _plane(
        64,
        48,
        (x, y) => (x * 3 + y * 5) % 256 + rng.nextInt(9) - 4,
      );

      expect(
        PhotoHash.distance(_hashOf(base, 64, 48), _hashOf(noisy, 64, 48)),
        lessThanOrEqualTo(16),
      );
    });

    test('respects a stride wider than the image', () {
      // Camera planes are commonly padded; ignoring bytesPerRow would shear
      // the sampled image and produce a garbage hash.
      int pixel(int x, int y) => (x * 3 + y * 5) % 256;
      final packed = _plane(64, 48, pixel);
      final padded = _plane(64, 48, pixel, bytesPerRow: 80);

      expect(
        _hashOf(packed, 64, 48),
        _hashOf(padded, 64, 48, stride: 80),
      );
    });

    test('returns 0 for empty input rather than throwing', () {
      expect(_hashOf(Uint8List(0), 0, 0), 0);
    });
  });

  group('distance', () {
    test('is 0 for the same hash', () {
      expect(PhotoHash.distance(0xDEADBEEF, 0xDEADBEEF), 0);
    });

    test('counts differing bits', () {
      expect(PhotoHash.distance(0x0, 0xF), 4);
      expect(PhotoHash.distance(0x1, 0x0), 1);
    });
  });

  group('bestDistance', () {
    test('picks the closest reference', () {
      final refs = [0x0, 0xFF, 0xF0];

      expect(PhotoHash.bestDistance(0xF1, refs), 1);
    });

    test('is maximally distant when nothing is registered', () {
      expect(PhotoHash.bestDistance(0x1234, const []), 64);
    });
  });

  group('encode/decode', () {
    test('round-trips a list of hashes', () {
      final hashes = [0x1, 0xABCDEF, 0x7FFFFFFFFFFFFFFF];

      expect(PhotoHash.decode(PhotoHash.encode(hashes)), hashes);
    });

    test('decodes empty or null to nothing', () {
      expect(PhotoHash.decode(null), isEmpty);
      expect(PhotoHash.decode(''), isEmpty);
    });

    test('skips malformed entries instead of throwing', () {
      expect(PhotoHash.decode('ff,zzz,10'), [0xff, 0x10]);
    });
  });
}
