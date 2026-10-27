import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The one Dart handler for the native `alarmplus/alarm_controls` channel.
///
/// A channel has a single handler: the widget code used to install its own
/// after the ring flow's, which silently replaced it, so the notification's
/// Snooze, volume-key snooze and "open from notification" all did nothing.
/// Features register the methods they handle here instead.
class NativeControls {
  NativeControls._();

  static const channel = MethodChannel('alarmplus/alarm_controls');

  static final _handlers = <String, Future<Object?> Function(Object? args)>{};
  static bool _bound = false;

  static void register(
    String method,
    Future<Object?> Function(Object? args) handler,
  ) {
    _handlers[method] = handler;
    if (_bound || kIsWeb) return;
    _bound = true;
    channel.setMethodCallHandler((call) async {
      final handler = _handlers[call.method];
      if (handler == null) {
        debugPrint('NativeControls: no handler for ${call.method}');
        return null;
      }
      return handler(call.arguments);
    });
  }

  @visibleForTesting
  static Future<Object?> dispatchForTest(String method, Object? args) =>
      _handlers[method]!(args);
}
