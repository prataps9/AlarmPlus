import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:alarm_plus/core/startup.dart';

void main() {
  group('runStartupStep', () {
    test('a clean step reports success', () async {
      var ran = false;
      expect(await runStartupStep('ok', () => ran = true), isTrue);
      expect(ran, isTrue);
    });

    test('an async failure is contained, not thrown', () async {
      final ok = await runStartupStep('boom', () async {
        throw StateError('plugin missing');
      });
      expect(ok, isFalse);
    });

    test('a synchronous throw is contained too', () async {
      final ok = await runStartupStep('boom', () => throw StateError('x'));
      expect(ok, isFalse);
    });

    test('a hung step is abandoned after the timeout', () async {
      final never = Completer<void>();
      final sw = Stopwatch()..start();
      final ok = await runStartupStep(
        'hang',
        () => never.future,
        timeout: const Duration(milliseconds: 50),
      );
      expect(ok, isFalse);
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });

    test('one failing step does not stop the ones after it', () async {
      final order = <String>[];
      await runStartupStep('a', () => order.add('a'));
      await runStartupStep('b', () => throw StateError('b'));
      await runStartupStep('c', () => order.add('c'));
      expect(order, ['a', 'c']);
    });
  });
}
