import 'package:flutter/material.dart';

import 'package:alarm_plus/features/sleep/models/sleep_entry.dart';
import 'package:alarm_plus/features/sleep/services/sleep_diary_service.dart';
import 'package:alarm_plus/core/services/smart_alarm_service.dart';
import 'package:alarm_plus/features/sleep/widgets/voice_memo_recorder.dart';

class SleepDiaryScreen extends StatefulWidget {
  const SleepDiaryScreen({super.key});

  static const routeName = '/sleep-diary';

  @override
  State<SleepDiaryScreen> createState() => _SleepDiaryScreenState();
}

class _SleepDiaryScreenState extends State<SleepDiaryScreen> {
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;
  bool _saving = false;

  int _sleepQuality = 3;
  int _morningMood = 3;
  int _deepSleepMinutes = 0;
  String? _voiceMemoPath;
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadEntry();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEntry() async {
    setState(() => _loading = true);
    final entry = await SleepDiaryService.getEntryForDate(_selectedDay);
    if (!mounted) return;
    setState(() {
      _sleepQuality = entry?.sleepQuality ?? 3;
      _morningMood = entry?.morningMood ?? 3;
      _deepSleepMinutes = entry?.deepSleepEstimate ?? 0;
      _voiceMemoPath = entry?.voiceMemoPath;
      _notesController.text = entry?.notes ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final entry = SleepEntry(
      date: SleepDiaryService.dateKey(_selectedDay),
      sleepQuality: _sleepQuality,
      morningMood: _morningMood,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      deepSleepEstimate: _deepSleepMinutes,
      voiceMemoPath: _voiceMemoPath,
    );
    await SleepDiaryService.saveEntry(entry);
    final award = await SmartAlarmService.awardXp(10);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved  +${award.earned} XP 🌙')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'SLEEP DIARY',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: Color(0xFF64748B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildDateStrip(),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('Sleep Quality'),
                    const SizedBox(height: 10),
                    _buildEmojiRow(
                      emojis: const ['😫', '😕', '😐', '😊', '😁'],
                      selected: _sleepQuality,
                      onSelect: (v) => setState(() => _sleepQuality = v),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Morning Mood'),
                    const SizedBox(height: 10),
                    _buildEmojiRow(
                      emojis: const ['😤', '😔', '😑', '🙂', '😄'],
                      selected: _morningMood,
                      onSelect: (v) => setState(() => _morningMood = v),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Deep Sleep Estimate'),
                    const SizedBox(height: 6),
                    Text(
                      _deepSleepMinutes == 0
                          ? 'Not sure'
                          : '$_deepSleepMinutes min',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Color(0xFF6366F1)),
                    ),
                    Slider(
                      value: _deepSleepMinutes.toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 12,
                      activeColor: const Color(0xFF6366F1),
                      inactiveColor: const Color(0xFFE2E8F0),
                      onChanged: (v) =>
                          setState(() => _deepSleepMinutes = v.round()),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Notes (optional)'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'How did you sleep? Any dreams?',
                        hintStyle:
                            const TextStyle(color: Color(0xFF94A3B8)),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                              color: Color(0xFF6366F1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionLabel('Voice Memo (optional)'),
                    const SizedBox(height: 10),
                    VoiceMemoRecorder(
                      initialPath: _voiceMemoPath,
                      onMemoSaved: (path) => setState(() => _voiceMemoPath = path),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0f172a),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : const Text('Save  +10 XP',
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final now = DateTime.now();
    return SizedBox(
      height: 76,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 7,
        itemBuilder: (context, i) {
          final day = now.subtract(Duration(days: 6 - i));
          final isSelected = _selectedDay.year == day.year &&
              _selectedDay.month == day.month &&
              _selectedDay.day == day.day;
          return FutureBuilder<SleepEntry?>(
            future: SleepDiaryService.getEntryForDate(day),
            builder: (context, snap) {
              final entry = snap.data;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDay = day);
                  _loadEntry();
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 52,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF0f172a)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF0f172a)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayLabel(day.weekday),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white60 : const Color(0xFF94A3B8),
                        ),
                      ),
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isSelected ? Colors.white : const Color(0xFF0f172a),
                        ),
                      ),
                      if (entry != null)
                        Text(
                          _qualityEmoji(entry.sleepQuality),
                          style: const TextStyle(fontSize: 12),
                        )
                      else
                        const SizedBox(height: 14),
                    ],
                  ),
                ),
              );
            },
          );
        },
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
                  ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : const Color(0xFFE2E8F0),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(emojis[i],
                  style: TextStyle(
                      fontSize: isSelected ? 30 : 24)),
            ),
          ),
        );
      }),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            color: Color(0xFF0f172a)),
      );

  String _dayLabel(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }

  String _qualityEmoji(int quality) {
    const emojis = ['', '😫', '😕', '😐', '😊', '😁'];
    return emojis[quality.clamp(1, 5)];
  }
}
