import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/sleep_entry.dart';
import 'package:alarm_plus/features/sleep/services/sleep_diary_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';

class MorningCheckInScreen extends StatefulWidget {
  const MorningCheckInScreen({super.key});

  static const routeName = '/morning-checkin';

  @override
  State<MorningCheckInScreen> createState() => _MorningCheckInScreenState();
}

class _MorningCheckInScreenState extends State<MorningCheckInScreen> {
  int _mood = 0;
  int _sleepRating = 0;
  final _notesController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_mood == 0 || _sleepRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate your mood and sleep')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final notes = _notesController.text.trim();
    // Merge into today's diary entry: writing a fresh one replaced it and
    // lost its voice memo, deep-sleep estimate, bedtime and wake time.
    final existing = await SleepDiaryService.getEntryForDate(now);
    final entry = SleepEntry(
      date: SleepDiaryService.dateKey(now),
      sleepQuality: _sleepRating,
      morningMood: _mood,
      notes: notes.isEmpty ? existing?.notes : notes,
      bedtime: existing?.bedtime,
      wakeTime: existing?.wakeTime,
      deepSleepEstimate: existing?.deepSleepEstimate,
      voiceMemoPath: existing?.voiceMemoPath,
    );
    await SleepDiaryService.saveEntry(entry);
    // Paid once a day, not on every check-in.
    if (await SmartAlarmService.claimDailyXp('morning_check_in')) {
      await SmartAlarmService.addXp(10);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(MorningMissionsScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0f172a),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context)
                      .pushReplacementNamed(MorningMissionsScreen.routeName),
                  child: const Text('Skip',
                      style: TextStyle(color: Colors.white54)),
                ),
              ]),
              const SizedBox(height: 8),
              const Text(
                'Morning\nCheck-In',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.1),
              ),
              const SizedBox(height: 6),
              const Text(
                'Quick log for your sleep diary',
                style: TextStyle(color: Colors.white54, fontSize: 15),
              ),
              const SizedBox(height: 36),
              const Text('How do you feel?',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 14),
              _buildEmojiRow(
                emojis: const ['😤', '😔', '😑', '🙂', '😄'],
                selected: _mood,
                onSelect: (v) => setState(() => _mood = v),
              ),
              const SizedBox(height: 28),
              const Text('Rate your sleep last night',
                  style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: 16)),
              const SizedBox(height: 14),
              _buildStarRow(),
              const SizedBox(height: 28),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Optional note...',
                  hintStyle: const TextStyle(color: Colors.white30),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.07),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF22C55E),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Done  +10 XP',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiRow({
    required List<String> emojis,
    required int selected,
    required ValueChanged<int> onSelect,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(5, (i) {
        final value = i + 1;
        final isSelected = selected == value;
        return GestureDetector(
          onTap: () => onSelect(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(emojis[i],
                  style: TextStyle(fontSize: isSelected ? 30 : 24)),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStarRow() {
    return Row(
      children: List.generate(5, (i) {
        final value = i + 1;
        return GestureDetector(
          onTap: () => setState(() => _sleepRating = value),
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(
              _sleepRating >= value ? Icons.star_rounded : Icons.star_outline_rounded,
              color: _sleepRating >= value
                  ? const Color(0xFFFBBF24)
                  : Colors.white24,
              size: 40,
            ),
          ),
        );
      }),
    );
  }
}
