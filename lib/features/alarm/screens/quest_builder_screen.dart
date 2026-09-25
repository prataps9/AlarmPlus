import 'package:flutter/material.dart';

import 'package:alarm_plus/shared/models/challenge_type.dart';
import 'package:alarm_plus/shared/models/quest_model.dart';
import 'package:alarm_plus/features/alarm/services/challenge_service.dart';

/// Returns a List of ChallengeType via Navigator.pop() when the user saves.
class QuestBuilderScreen extends StatefulWidget {
  const QuestBuilderScreen({super.key, this.initialSteps});
  static const routeName = '/quest-builder';

  final List<ChallengeType>? initialSteps;

  @override
  State<QuestBuilderScreen> createState() => _QuestBuilderScreenState();
}

class _QuestBuilderScreenState extends State<QuestBuilderScreen> {
  late List<ChallengeType> _steps;

  static const _pickable = ChallengeService.questPickable;

  @override
  void initState() {
    super.initState();
    _steps = widget.initialSteps != null
        ? List.from(widget.initialSteps!)
        : WakeQuest.ultimatePreset().steps.map((s) => s.challengeType).toList();
  }

  void _addStep(ChallengeType type) {
    if (_steps.length >= 4) return;
    setState(() => _steps.add(type));
  }

  void _removeStep(int index) {
    setState(() => _steps.removeAt(index));
  }

  void _saveAndPop() {
    if (_steps.isEmpty) return;
    Navigator.of(context).pop(_steps);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quest Builder',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          TextButton(
            onPressed: _saveAndPop,
            child: const Text('Save',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6366F1),
                    fontSize: 16)),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPresetBanner(),
              const SizedBox(height: 20),
              const Text('Your Quest Steps',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                '${_steps.length}/4 steps • Drag to reorder',
                style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              _buildStepList(),
              const SizedBox(height: 24),
              const Text('Add a Step',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              _buildPickerGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetBanner() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _steps = WakeQuest.ultimatePreset()
              .steps
              .map((s) => s.challengeType)
              .toList();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          const Icon(Icons.rocket_launch_rounded,
              color: Colors.white, size: 22),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Ultimate Wake Quest',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              Text('Shake → Steps → Trivia → Eyes Open',
                  style: TextStyle(color: Colors.white70, fontSize: 12)),
            ]),
          ),
          const Text('Load',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _buildStepList() {
    if (_steps.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Column(children: [
          Icon(Icons.playlist_add_rounded,
              color: Color(0xFFCBD5E1), size: 36),
          SizedBox(height: 8),
          Text('Add steps from the grid below',
              style: TextStyle(color: Color(0xFF94A3B8))),
        ]),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _steps.length,
      onReorderItem: (oldIndex, newIndex) {
        setState(() {
          final item = _steps.removeAt(oldIndex);
          _steps.insert(newIndex, item);
        });
      },
      itemBuilder: (context, i) {
        final type = _steps[i];
        return _StepTile(
          key: ValueKey('$type-$i'),
          index: i,
          type: type,
          onRemove: () => _removeStep(i),
        );
      },
    );
  }

  Widget _buildPickerGrid() {
    final canAdd = _steps.length < 4;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _pickable.map((type) {
        final alreadyAdded = _steps.contains(type);
        return GestureDetector(
          onTap: canAdd && !alreadyAdded ? () => _addStep(type) : null,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (!canAdd || alreadyAdded) ? 0.4 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: alreadyAdded
                    ? const Color(0xFFEEF2FF)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: alreadyAdded
                        ? const Color(0xFF6366F1)
                        : const Color(0xFFE2E8F0),
                    width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(_iconFor(type),
                    size: 16,
                    color: alreadyAdded
                        ? const Color(0xFF6366F1)
                        : const Color(0xFF475467)),
                const SizedBox(width: 6),
                Text(ChallengeService.label(type),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: alreadyAdded
                            ? const Color(0xFF6366F1)
                            : const Color(0xFF475467))),
              ]),
            ),
          ),
        );
      }).toList(),
    );
  }

  IconData _iconFor(ChallengeType type) {
    switch (type) {
      case ChallengeType.math:
        return Icons.calculate_rounded;
      case ChallengeType.memoryPattern:
        return Icons.grid_view_rounded;
      case ChallengeType.shakeToWake:
        return Icons.vibration_rounded;
      case ChallengeType.typing:
        return Icons.keyboard_rounded;
      case ChallengeType.barcodeScan:
        return Icons.qr_code_rounded;
      case ChallengeType.trivia:
        return Icons.quiz_rounded;
      case ChallengeType.wordScramble:
        return Icons.text_fields_rounded;
      case ChallengeType.stepCounter:
        return Icons.directions_walk_rounded;
      case ChallengeType.eyeOpen:
        return Icons.remove_red_eye_rounded;
      case ChallengeType.squatReps:
        return Icons.fitness_center_rounded;
      case ChallengeType.photoProof:
        return Icons.photo_camera_rounded;
      case ChallengeType.voiceRepeat:
        return Icons.record_voice_over_rounded;
      case ChallengeType.random:
        return Icons.shuffle_rounded;
    }
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    super.key,
    required this.index,
    required this.type,
    required this.onRemove,
  });

  final int index;
  final ChallengeType type;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text('${index + 1}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF6366F1))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(ChallengeService.label(type),
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              color: Color(0xFF94A3B8), size: 20),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: onRemove,
        ),
        const SizedBox(width: 8),
        const Icon(Icons.drag_handle_rounded,
            color: Color(0xFFCBD5E1), size: 20),
      ]),
    );
  }
}
