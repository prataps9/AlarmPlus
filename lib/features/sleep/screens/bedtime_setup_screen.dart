import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/bedtime_schedule.dart';
import 'package:alarm_plus/features/sleep/services/bedtime_service.dart';
import 'package:alarm_plus/shared/utils/time_format.dart';

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
    final schedule = BedtimeSchedule(
      targetBedtime: _bedtime,
      windDownMinutes: _windDownMinutes,
      isEnabled: _isEnabled,
    );
    await BedtimeService.save(schedule);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bedtime schedule saved!')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final timeLabel = formatClockTime(_bedtime, context: context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'WIND DOWN',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF64748B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Enable Wind Down', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      Text('Get notified before bedtime', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
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
                          : const Color(0xFFE2E8F0)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('TARGET BEDTIME', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickBedtime,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bedtime_rounded, color: Color(0xFF6366F1)),
                    const SizedBox(width: 12),
                    Text(timeLabel, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                    const Spacer(),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('WIND DOWN DURATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 2, color: Color(0xFF94A3B8))),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [15, 30, 45, 60].map((min) {
                final selected = _windDownMinutes == min;
                return ChoiceChip(
                  label: Text('$min min'),
                  selected: selected,
                  selectedColor: const Color(0xFF0F172A),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => setState(() => _windDownMinutes = min),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ll be notified at ${_windDownTimeLabel()} to start winding down',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
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
    final wrapped = (totalMin + 24 * 60) % (24 * 60);
    return formatClockTime(
      TimeOfDay(hour: wrapped ~/ 60, minute: wrapped % 60),
      context: context,
    );
  }
}
