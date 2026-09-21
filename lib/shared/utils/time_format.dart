import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Whether the device is set to 24-hour time.
///
/// Prefers [MediaQuery] when a context is available, so widgets rebuild if the
/// setting changes while the app is open. Models and services that have no
/// context fall back to the platform value, which needs no binding and so
/// stays usable from plain unit tests.
bool uses24HourFormat([BuildContext? context]) {
  if (context != null) {
    final query = MediaQuery.maybeOf(context);
    if (query != null) {
      return query.alwaysUse24HourFormat;
    }
  }
  return ui.PlatformDispatcher.instance.alwaysUse24HourFormat;
}

/// A full clock label: `19:30` on a 24-hour device, `7:30 PM` on a 12-hour one.
String formatClockTime(
  TimeOfDay time, {
  BuildContext? context,
  bool? use24h,
}) {
  final minute = time.minute.toString().padLeft(2, '0');
  if (use24h ?? uses24HourFormat(context)) {
    return '${time.hour.toString().padLeft(2, '0')}:$minute';
  }
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  return '$hour:$minute ${time.period == DayPeriod.am ? 'AM' : 'PM'}';
}

/// [formatClockTime] for a [DateTime].
String formatClockDateTime(
  DateTime value, {
  BuildContext? context,
  bool? use24h,
}) =>
    formatClockTime(
      TimeOfDay.fromDateTime(value),
      context: context,
      use24h: use24h,
    );

/// The digits of a split display (`19:30` / `07:30`), where the AM/PM marker
/// is rendered separately at its own size — see [clockPeriodLabel].
String clockDigits(
  TimeOfDay time, {
  BuildContext? context,
  bool? use24h,
}) {
  final minute = time.minute.toString().padLeft(2, '0');
  final hour = (use24h ?? uses24HourFormat(context))
      ? time.hour
      : (time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod);
  return '${hour.toString().padLeft(2, '0')}:$minute';
}

/// The AM/PM marker for a split display — empty on a 24-hour device, which
/// has no period to show.
String clockPeriodLabel(
  TimeOfDay time, {
  BuildContext? context,
  bool? use24h,
}) {
  if (use24h ?? uses24HourFormat(context)) {
    return '';
  }
  return time.hour >= 12 ? 'PM' : 'AM';
}
