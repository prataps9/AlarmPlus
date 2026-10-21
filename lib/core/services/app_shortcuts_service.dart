import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';

/// Launcher-icon shortcuts (long-press the Alarm+ icon on Android, or
/// 3D-touch it on iOS): jump straight to the things people open the app for.
class AppShortcutsService {
  AppShortcutsService._();

  static const _quickActions = QuickActions();

  /// Shortcut type → named route. Types are stable ids; don't rename them,
  /// launchers pin shortcuts by type.
  static const routes = <String, String>{
    'new_alarm': '/alarms',
    'nap': '/nap-timer',
    'sleep_sounds': '/sleep-sounds',
    'focus': '/focus-timer',
  };

  static const _items = [
    // `icon` names a drawable in android/app/src/main/res/drawable.
    ShortcutItem(type: 'new_alarm', localizedTitle: 'New alarm', icon: 'ic_shortcut_alarm_add'),
    ShortcutItem(type: 'nap', localizedTitle: 'Power nap', icon: 'ic_shortcut_nap'),
    ShortcutItem(type: 'sleep_sounds', localizedTitle: 'Sleep sounds', icon: 'ic_shortcut_sleep_sounds'),
    ShortcutItem(type: 'focus', localizedTitle: 'Focus timer', icon: 'ic_shortcut_focus'),
  ];

  static Future<void> init() async {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return;
    }
    try {
      // Also receives the shortcut that cold-started the app.
      await _quickActions.initialize(_open);
      await _quickActions.setShortcutItems(_items);
    } catch (e) {
      debugPrint('App shortcuts unavailable: $e');
    }
  }

  static void _open(String type) {
    final route = routes[type];
    if (route == null) return;
    unawaited(_pushWhenReady(route));
  }

  /// On a cold start the navigator doesn't exist yet. The route is pushed
  /// above the splash, which then replaces itself underneath it (see
  /// `replaceRouteInPlace`), so the user lands on the shortcut's screen with
  /// Home behind it for Back.
  static Future<void> _pushWhenReady(String route) async {
    for (var i = 0; i < 50; i++) {
      final nav = appNavigatorKey.currentState;
      if (nav != null) {
        unawaited(nav.pushNamed(route));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
}
