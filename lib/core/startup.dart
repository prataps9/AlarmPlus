import 'dart:async';

import 'package:flutter/foundation.dart';

/// Runs one launch step so that it can never stop the app from opening.
///
/// `main()` initialises a dozen plugins before the first frame. If any one of
/// them threw on some phone, `runApp` was never reached and the user stared at
/// the splash forever; if one hung, the same. Each step now gets its own
/// error handling and a time limit.
///
/// Returns whether the step finished cleanly; callers normally ignore it
/// because a failed step is logged and the app carries on without that
/// feature.
Future<bool> runStartupStep(
  String name,
  FutureOr<void> Function() step, {
  Duration timeout = const Duration(seconds: 6),
}) async {
  try {
    await Future<void>.sync(step).timeout(timeout);
    return true;
  } on TimeoutException {
    debugPrint('Startup step "$name" timed out after $timeout; continuing.');
  } catch (e, st) {
    debugPrint('Startup step "$name" failed: $e\n$st');
  }
  return false;
}
