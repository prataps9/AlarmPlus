import 'dart:async';

import 'package:flutter/material.dart';

import 'package:alarm_plus/features/focus/models/nap_preset.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';
import 'package:alarm_plus/shared/widgets/focus_ring.dart';

class NapTimerScreen extends StatefulWidget {
  const NapTimerScreen({super.key});

  static const routeName = '/nap-timer';

  @override
  State<NapTimerScreen> createState() => _NapTimerScreenState();
}

class _NapTimerScreenState extends State<NapTimerScreen> {
  bool _loading = true;
  bool _napActive = false;
  int _remainingSeconds = 0;
  int _totalSeconds = 0;
  NapPresetType? _selectedPreset;
  int _customMinutes = 30;
  List<Map<String, dynamic>> _history = [];
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final active = await NapService.isNapActive();
    final history = await NapService.getNapHistory();
    int remaining = 0;
    int total = 0;
    if (active) {
      remaining = await NapService.getRemainingSeconds();
      total = await NapService.getDurationSeconds();
    }
    if (!mounted) return;
    setState(() {
      _napActive = active && remaining > 0;
      _remainingSeconds = remaining;
      _totalSeconds = total;
      _history = history;
      _loading = false;
    });
    if (_napActive) _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final r = await NapService.getRemainingSeconds();
      setState(() {
        _remainingSeconds = r;
        if (r <= 0) {
          _napActive = false;
          _ticker?.cancel();
        }
      });
    });
  }

  Future<void> _startNap(int minutes) async {
    await NapService.scheduleNap(minutes);
    if (!mounted) return;
    setState(() {
      _napActive = true;
      _remainingSeconds = minutes * 60;
      _totalSeconds = minutes * 60;
    });
    _startTicker();
  }

  Future<void> _cancelNap() async {
    await NapService.cancelNap();
    _ticker?.cancel();
    if (!mounted) return;
    setState(() {
      _napActive = false;
      _remainingSeconds = 0;
    });
  }

  int get _selectedMinutes {
    if (_selectedPreset == NapPresetType.custom) return _customMinutes;
    final preset = NapPreset.presets.where((p) => p.type == _selectedPreset).firstOrNull;
    return preset?.durationMinutes ?? 20;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1e3a5f),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1e3a5f),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'NAP TIMER',
          style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3),
        ),
      ),
      body: _napActive ? _buildRunningState() : _buildIdleState(),
    );
  }

  Widget _buildRunningState() {
    final mins = _remainingSeconds ~/ 60;
    final secs = _remainingSeconds % 60;
    final label = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    // 1 → 0 as the nap counts down. It used to divide the remaining time by
    // itself, so the ring was always full.
    final progress = _totalSeconds <= 0
        ? 1.0
        : (_remainingSeconds / _totalSeconds).clamp(0.0, 1.0);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
        child: Column(
          children: [
            const Text(
              'Rest and recharge',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Wake up in ${(_remainingSeconds / 60).ceil()} min',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            _NapRing(progress: progress, timeLabel: label),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cancelNap,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38),
                      foregroundColor: Colors.white70,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40)),
                    ),
                    child: const Text('Cancel Nap'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await _cancelNap();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Nap ended early')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF22C55E),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(40)),
                    ),
                    child: const Text('Wake Now',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdleState() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                '💤',
                style: TextStyle(fontSize: 56),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Choose your nap length',
                style: TextStyle(color: Colors.white70, fontSize: 15),
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.4,
              children: [
                ...NapPreset.presets.map((p) => _presetCard(p)),
                _customCard(),
              ],
            ),
            if (_selectedPreset == NapPresetType.custom) ...[
              const SizedBox(height: 20),
              const Text('Custom duration',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Colors.white54),
                  Expanded(
                    child: Slider(
                      value: _customMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: Colors.white12,
                      label: '$_customMinutes min',
                      onChanged: (v) =>
                          setState(() => _customMinutes = v.round()),
                    ),
                  ),
                  Text(
                    '$_customMinutes min',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 16),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            if (_selectedPreset != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _startNap(_selectedMinutes),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                  child: Text(
                    'Start Nap · $_selectedMinutes min',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('Recent Naps',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              const SizedBox(height: 12),
              ..._history.take(3).map((h) => _buildHistoryRow(h)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _presetCard(NapPreset preset) {
    final isSelected = _selectedPreset == preset.type;
    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = preset.type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(preset.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              preset.label,
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            Text(
              '${preset.durationMinutes} min',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _customCard() {
    final isSelected = _selectedPreset == NapPresetType.custom;
    return GestureDetector(
      onTap: () => setState(() => _selectedPreset = NapPresetType.custom),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF6366F1).withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('⚙️', style: TextStyle(fontSize: 28)),
            const SizedBox(height: 6),
            Text(
              'Custom',
              style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
            Text(
              isSelected ? '$_customMinutes min' : 'Choose duration',
              style: const TextStyle(color: Colors.white38, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryRow(Map<String, dynamic> h) {
    final duration = h['duration'] as int? ?? 0;
    final rating = h['rating'] as int? ?? 0;
    final ts = h['timestamp'] as String? ?? '';
    final date = ts.isNotEmpty ? ts.substring(0, 10) : '—';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Text('😴', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  NapService.formatDuration(duration),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
                Text(date,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 12)),
              ],
            ),
          ),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i < rating
                    ? const Color(0xFFFBBF24)
                    : Colors.white.withValues(alpha: 0.2),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NapRing extends StatelessWidget {
  const _NapRing({required this.progress, required this.timeLabel});
  final double progress;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    return FocusRing(
      progress: progress,
      timeLabel: timeLabel,
    );
  }
}
