import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:alarm_plus/features/missions/models/mission_model.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';

class MorningMissionsScreen extends StatefulWidget {
  const MorningMissionsScreen({super.key});

  static const routeName = '/morning-missions';

  @override
  State<MorningMissionsScreen> createState() => _MorningMissionsScreenState();
}

class _MorningMissionsScreenState extends State<MorningMissionsScreen> {
  List<MissionModel> _missions = [];
  bool _loading = true;
  int _totalEarnedXp = 0;
  late Timer _expiryTimer;
  Duration _timeToNoon = Duration.zero;
  int _missionStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _startExpiryTimer();
  }

  @override
  void dispose() {
    _expiryTimer.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final missions = await SmartAlarmService.getTodayMissions();
    final streak = await SmartAlarmService.getMissionStreak();
    final now = DateTime.now();
    final noon = DateTime(now.year, now.month, now.day, 12, 0, 0);
    if (!mounted) return;
    setState(() {
      _missions = missions;
      _missionStreak = streak;
      _timeToNoon = noon.isAfter(now) ? noon.difference(now) : Duration.zero;
      _loading = false;
    });
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final now = DateTime.now();
      final noon = DateTime(now.year, now.month, now.day, 12, 0, 0);
      if (mounted) {
        setState(() {
          _timeToNoon = noon.isAfter(now) ? noon.difference(now) : Duration.zero;
        });
      }
    });
  }

  Future<void> _toggleMission(int index) async {
    if (_missions[index].isCompleted) return;
    HapticFeedback.lightImpact();
    final xp = await SmartAlarmService.completeMission(_missions[index].id);
    setState(() {
      _missions[index].isCompleted = true;
      _totalEarnedXp += xp;
    });
  }

  Future<void> _showAddCustomMission() async {
    // The dialog owns its text controller: this used to dispose it right
    // after an un-awaited showDialog, while the field was still using it.
    final mission = await showDialog<(String, String)>(
      context: context,
      builder: (ctx) => const _AddMissionDialog(),
    );
    if (mission == null) return;
    await SmartAlarmService.addCustomMission(mission.$1, mission.$2);
    if (!mounted) return;
    // Today's three missions are already drawn, so a new one joins the pool
    // that tomorrow's are picked from. Adding it to today's list would make
    // every new mission a fresh +XP and move the all-done streak goalpost.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added. It joins your mission pool from tomorrow.'),
      ),
    );
    await _load();
  }

  String _formatDuration(Duration d) {
    if (d.inMinutes <= 0) return 'Expired';
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  bool get _allCompleted => _missions.every((m) => m.isCompleted);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Morning Missions', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (_timeToNoon > Duration.zero)
              Text(
                'Expires in ${_formatDuration(_timeToNoon)}',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, fontWeight: FontWeight.w400),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            onPressed: _showAddCustomMission,
            tooltip: 'Add custom mission',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
              child: Column(
                children: [
                  if (_missionStreak > 0)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF97316).withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.35)),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Text(
                            '$_missionStreak-day mission streak!',
                            style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 300.ms),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _missions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final mission = _missions[i];
                        return _MissionTile(
                          mission: mission,
                          onTap: () => _toggleMission(i),
                        ).animate().fadeIn(delay: (i * 80).ms, duration: 300.ms).slideY(begin: 0.2, end: 0);
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 400),
                    crossFadeState: _allCompleted ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF22C55E),
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Text(
                        'All done! 🎉 +$_totalEarnedXp XP',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ).animate().scale(begin: const Offset(0.8, 0.8), duration: 400.ms, curve: Curves.elasticOut),
                    secondChild: Text(
                      '${_missions.where((m) => m.isCompleted).length} of ${_missions.length} completed · +$_totalEarnedXp XP so far',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MissionTile extends StatelessWidget {
  const _MissionTile({required this.mission, required this.onTap});
  final MissionModel mission;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: mission.isCompleted ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: mission.isCompleted
              ? const Color(0xFF22C55E).withValues(alpha: 0.08)
              : scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: mission.isCompleted ? const Color(0xFF86EFAC) : scheme.outlineVariant,
            width: 1.5,
          ),
          boxShadow: mission.isCompleted
              ? null
              : const [BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Text(mission.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mission.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      decoration: mission.isCompleted ? TextDecoration.lineThrough : null,
                      color: mission.isCompleted ? scheme.onSurfaceVariant : scheme.onSurface,
                    ),
                  ),
                  Text(
                    '+${mission.xpReward} XP',
                    style: TextStyle(
                      fontSize: 12,
                      color: mission.isCompleted ? const Color(0xFF86EFAC) : const Color(0xFF22C55E),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: mission.isCompleted ? const Color(0xFF22C55E) : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: mission.isCompleted ? const Color(0xFF22C55E) : scheme.outline,
                  width: 2,
                ),
              ),
              child: mission.isCompleted
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AddMissionDialog extends StatefulWidget {
  const _AddMissionDialog();

  @override
  State<_AddMissionDialog> createState() => _AddMissionDialogState();
}

class _AddMissionDialogState extends State<_AddMissionDialog> {
  static const _icons = ['⭐', '💪', '📚', '🎯', '🌿', '💡', '🏃', '☕', '🎵', '❤️'];

  final _titleCtrl = TextEditingController();
  String _selectedIcon = '⭐';

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Mission'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(hintText: 'What do you want to do?'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _icons.map((ic) {
              return GestureDetector(
                onTap: () => setState(() => _selectedIcon = ic),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIcon == ic
                        ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _selectedIcon == ic ? const Color(0xFF6366F1) : Colors.transparent,
                    ),
                  ),
                  child: Text(ic, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) return;
            Navigator.pop(context, (title, _selectedIcon));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
