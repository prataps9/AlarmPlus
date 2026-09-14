import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/features/alarm/models/alarm_model.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/focus/services/focus_timer_service.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';

enum _IslandKind { nap, focus, upcomingAlarm }

class _IslandState {
  const _IslandState({
    required this.kind,
    required this.label,
    required this.remaining,
  });

  final _IslandKind kind;
  final String label;
  final Duration remaining;
}

/// A compact pinned pill showing whatever's live right now: an active nap,
/// an active focus session, or an alarm about to ring within the hour —
/// the in-app, cross-platform counterpart to the Android chronometer
/// notification in [LiveTimerNotificationService]. Visible on iOS too, but
/// only while the app is foregrounded (unlike the Android notification,
/// which survives backgrounding). Hidden entirely when nothing is live.
class LiveStatusIsland extends ConsumerStatefulWidget {
  const LiveStatusIsland({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<LiveStatusIsland> createState() => _LiveStatusIslandState();
}

class _LiveStatusIslandState extends ConsumerState<LiveStatusIsland> {
  Timer? _ticker;
  _IslandState? _state;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (AlarmRingFlow.currentRingingId != 0) {
      _apply(null);
      return;
    }

    if (await NapService.isNapActive()) {
      final remaining = await NapService.getRemainingSeconds();
      if (remaining > 0) {
        _apply(_IslandState(
          kind: _IslandKind.nap,
          label: 'Nap',
          remaining: Duration(seconds: remaining),
        ));
        return;
      }
    }

    if (await FocusTimerService.isActive()) {
      final remaining = await FocusTimerService.getRemainingSeconds();
      if (remaining > 0) {
        _apply(_IslandState(
          kind: _IslandKind.focus,
          label: 'Focus',
          remaining: Duration(seconds: remaining),
        ));
        return;
      }
    }

    final alarms = ref.read(alarmsListProvider).valueOrNull;
    if (alarms != null) {
      final now = DateTime.now();
      AlarmModel? soonest;
      Duration? soonestGap;
      for (final alarm in alarms.where((a) => a.isEnabled)) {
        final next = alarm.nextDateTimeFrom(now);
        final gap = next.difference(now);
        if (gap <= const Duration(hours: 1) &&
            (soonestGap == null || gap < soonestGap)) {
          soonest = alarm;
          soonestGap = gap;
        }
      }
      if (soonest != null && soonestGap != null) {
        _apply(_IslandState(
          kind: _IslandKind.upcomingAlarm,
          label: soonest.label.isEmpty ? 'Alarm' : soonest.label,
          remaining: soonestGap,
        ));
        return;
      }
    }

    _apply(null);
  }

  void _apply(_IslandState? next) {
    if (!mounted) return;
    setState(() => _state = next);
  }

  void _onTap() {
    final state = _state;
    if (state == null) return;
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    switch (state.kind) {
      case _IslandKind.nap:
        navigator.pushNamed(NapTimerScreen.routeName);
      case _IslandKind.focus:
        navigator.pushNamed(FocusTimerScreen.routeName);
      case _IslandKind.upcomingAlarm:
        navigator.pushNamed('/app');
    }
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  IconData _iconFor(_IslandKind kind) {
    switch (kind) {
      case _IslandKind.nap:
        return Icons.bedtime_rounded;
      case _IslandKind.focus:
        return Icons.timer_rounded;
      case _IslandKind.upcomingAlarm:
        return Icons.alarm_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep the upcoming-alarm math fresh whenever alarms change, without
    // waiting for the next per-second tick.
    ref.listen(alarmsListProvider, (_, __) => _refresh());

    final state = _state;
    final theme = Theme.of(context);

    return Stack(
      children: [
        widget.child,
        if (state != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Material(
                      color: theme.colorScheme.inverseSurface,
                      borderRadius: BorderRadius.circular(24),
                      elevation: 4,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _onTap,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _iconFor(state.kind),
                                size: 16,
                                color: theme.colorScheme.onInverseSurface,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${state.label} · ${_format(state.remaining)}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onInverseSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
