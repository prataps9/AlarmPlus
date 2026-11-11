import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';

/// Puts a screen on the app's dark palette whatever the phone is set to.
///
/// For the bedtime screens (wind-down, sleep sounds, nap, morning check-in):
/// they are used in a dark room, where a white page would be glaring. It is
/// the same dark theme as everywhere else, not a separate set of colours, so
/// the screens inside read their colours from `Theme.of(context)` as usual.
///
/// It must sit ABOVE the screen (around the route builder), so the screen's
/// own `build(context)` already sees the dark theme.
class NightTheme extends StatelessWidget {
  const NightTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) =>
      Theme(data: AppTheme.dark, child: child);
}
