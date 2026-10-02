import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/clock/models/clock_models.dart';
import 'package:alarm_plus/features/clock/services/clock_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

/// Local time up top, then a list of world cities — like the Clock tab in
/// the stock Android clock app.
class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  List<WorldCity> _cities = const [];
  late Timer _tick;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    ClockService.loadCities().then((c) {
      if (mounted) setState(() => _cities = c);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  Future<void> _addCity() async {
    final picked = await showModalBottomSheet<WorldCity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CityPicker(exclude: _cities.map((c) => c.name).toSet()),
    );
    if (picked == null) return;
    setState(() => _cities = [..._cities, picked]);
    await ClockService.saveCities(_cities);
  }

  Future<void> _remove(WorldCity city) async {
    setState(() => _cities = _cities.where((c) => c != city).toList());
    await ClockService.saveCities(_cities);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final use24h = MediaQuery.of(context).alwaysUse24HourFormat;
    final timeFmt = DateFormat(use24h ? 'HH:mm' : 'h:mm');
    final nowUtc = _now.toUtc();
    final localOffset = _now.timeZoneOffset;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add city',
        onPressed: _addCity,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 96),
          children: [
            Text('Clock',
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w700, fontSize: 30)),
            const SizedBox(height: Spacing.xxl),
            Center(
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        timeFmt.format(_now),
                        style: const TextStyle(
                            fontSize: 72, fontWeight: FontWeight.w300, height: 1),
                      ),
                      if (!use24h) ...[
                        const SizedBox(width: 6),
                        Text(DateFormat('a').format(_now),
                            style: const TextStyle(fontSize: 22)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(DateFormat('EEE, d MMMM').format(_now),
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: Spacing.xxxl),
            if (_cities.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('Tap + to add a city',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            for (final city in _cities)
              Dismissible(
                key: ValueKey(city.name),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: scheme.error.withValues(alpha: 0.12),
                  child: Icon(Icons.delete_outline, color: scheme.error),
                ),
                onDismissed: (_) => _remove(city),
                child: _CityRow(
                  city: city,
                  time: CityTime.of(city, nowUtc, localOffset),
                  timeFmt: timeFmt,
                  use24h: use24h,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CityRow extends StatelessWidget {
  const _CityRow({
    required this.city,
    required this.time,
    required this.timeFmt,
    required this.use24h,
  });

  final WorldCity city;
  final CityTime time;
  final DateFormat timeFmt;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(city.name, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  '${time.dayLabel}, ${TimeFormat.offsetFromLocal(time.offsetFromLocal)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            timeFmt.format(time.wallTime),
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w300),
          ),
          if (!use24h) ...[
            const SizedBox(width: 4),
            Text(DateFormat('a').format(time.wallTime),
                style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _CityPicker extends StatefulWidget {
  const _CityPicker({required this.exclude});

  final Set<String> exclude;

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final matches = WorldCity.all
        .where((c) => !widget.exclude.contains(c.name))
        .where((c) =>
            q.isEmpty ||
            c.name.toLowerCase().contains(q) ||
            c.country.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search city or country',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final c in matches)
                  ListTile(
                    title: Text(c.name),
                    subtitle: Text(c.country),
                    onTap: () => Navigator.of(context).pop(c),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
