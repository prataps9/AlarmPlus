import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';

class BedtimeSetupScreen extends StatefulWidget {
  const BedtimeSetupScreen({super.key});

  static const routeName = '/bedtime-setup';

  @override
  State<BedtimeSetupScreen> createState() => _BedtimeSetupScreenState();
}

class _BedtimeSetupScreenState extends State<BedtimeSetupScreen> {
  TimeOfDay _bedtime = const TimeOfDay(hour: 22, minute: 30);
  int _windDownMinutes = 30;
  bool _isEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final schedule = await BedtimeService.load();
    if (schedule != null && mounted) {
      setState(() {
        _bedtime = schedule.targetBedtime;
        _windDownMinutes = schedule.windDownMinutes;
        _isEnabled = schedule.isEnabled;
      });
    }
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(context: context, initialTime: _bedtime);
    if (picked != null) setState(() => _bedtime = picked);
  }

  Future<void> _save() async {
    // Start from what's saved: building a fresh schedule reset the sleep
    // goal (set on the Bedtime card) to the 8-hour default.
    final saved = await BedtimeService.load();
    final base = saved ??
        BedtimeSchedule(targetBedtime: _bedtime);
    await BedtimeService.save(base.copyWith(
      targetBedtime: _bedtime,
      windDownMinutes: _windDownMinutes,
      isEnabled: _isEnabled,
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bedtime schedule saved!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final h = _bedtime.hour;
    final m = _bedtime.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final displayH = h % 12 == 0 ? 12 : h % 12;
    final timeLabel = '$displayH:${m.toString().padLeft(2, '0')} $period';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'WIND DOWN',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: scheme.onSurfaceVariant),
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enable Wind Down', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: scheme.onSurface)),
                      Text('Get notified before bedtime', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: (v) => setState(() => _isEnabled = v),
                  thumbColor: WidgetStatePropertyAll(Colors.white),
                  trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
                      states.contains(WidgetState.selected)
                          ? const Color(0xFF22C55E)
                          : scheme.outlineVariant),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Text('TARGET BEDTIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickBedtime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bedtime_rounded, color: Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    Text(timeLabel, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: scheme.onSurface)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('WIND DOWN DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [15, 30, 45, 60].map((min) {
                final selected = _windDownMinutes == min;
                return ChoiceChip(
                  label: Text('$min min'),
                  selected: selected,
                  selectedColor: scheme.onSurface,
                  checkmarkColor: scheme.surface,
                  labelStyle: TextStyle(
                    color: selected ? scheme.surface : scheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _windDownMinutes = min),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ll be notified at ${_windDownTimeLabel()} to start winding down',
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.onSurface,
                  foregroundColor: scheme.surface,
                  minimumSize: const Size(double.infinity, 58),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                ),
                child: const Text('Save Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _windDownTimeLabel() {
    final totalMin = _bedtime.hour * 60 + _bedtime.minute - _windDownMinutes;
    final h = (totalMin ~/ 60) % 24;
    final m = totalMin % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final dH = h % 12 == 0 ? 12 : h % 12;
    return '$dH:${m.toString().padLeft(2, '0')} $period';
  }
}
