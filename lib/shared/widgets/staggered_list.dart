import 'package:flutter/material.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';

/// A scrolling list whose children rise and fade in one after another the
/// first time it appears. One [AnimationController] drives all of them (each
/// child gets its own slice of it), so there are no per-item timers, and it
/// does nothing when the system asks for reduced motion.
class StaggeredListView extends StatefulWidget {
  const StaggeredListView({
    super.key,
    required this.children,
    this.padding,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.step = const Duration(milliseconds: 55),
    this.maxStaggered = 8,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  /// Delay between one child and the next.
  final Duration step;

  /// Children after this many appear together, so a long list doesn't make
  /// the user wait for the bottom.
  final int maxStaggered;

  @override
  State<StaggeredListView> createState() => _StaggeredListViewState();
}

class _StaggeredListViewState extends State<StaggeredListView>
    with SingleTickerProviderStateMixin {
  static const _each = Motion.slow;
  late final AnimationController _controller;
  bool _started = false;

  Duration get _total =>
      _each + widget.step * widget.maxStaggered;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _slice(int i) {
    final totalMs = _total.inMilliseconds;
    final start = (widget.step.inMilliseconds * i.clamp(0, widget.maxStaggered)) /
        totalMs;
    final end = start + _each.inMilliseconds / totalMs;
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
          curve: Motion.standard),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.children;
    return ListView.builder(
      padding: widget.padding,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      itemCount: items.length,
      itemBuilder: (context, i) {
        final a = _slice(i);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(a),
            child: items[i],
          ),
        );
      },
    );
  }
}
