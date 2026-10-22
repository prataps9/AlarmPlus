import 'package:flutter/material.dart';

import 'package:alarm_plus/features/location/models/location_alarm.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';
import 'package:alarm_plus/features/location/screens/location_picker_screen.dart';

class LocationAlarmScreen extends StatefulWidget {
  const LocationAlarmScreen({super.key});

  static const routeName = '/location-alarms';

  @override
  State<LocationAlarmScreen> createState() => _LocationAlarmScreenState();
}

class _LocationAlarmScreenState extends State<LocationAlarmScreen> {
  late Future<List<LocationAlarm>> _alarmsFuture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _alarmsFuture = LocationAlarmService.loadAll();
    });
  }

  Future<void> _addNew() async {
    final result = await Navigator.of(context).pushNamed(LocationPickerScreen.routeName);
    if (result != null) _refresh();
  }

  Future<void> _delete(LocationAlarm alarm) async {
    await LocationAlarmService.delete(alarm.id);
    _refresh();
  }

  Future<void> _toggle(LocationAlarm alarm, bool enabled) async {
    await LocationAlarmService.save(alarm.copyWith(isEnabled: enabled));
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(
          'LOCATION ALARMS',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: scheme.onSurfaceVariant),
        ),
        backgroundColor: scheme.surface,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNew,
        backgroundColor: scheme.onSurface,
        foregroundColor: scheme.surface,
        child: const Icon(Icons.add_location_alt_rounded),
      ),
      body: FutureBuilder<List<LocationAlarm>>(
        future: _alarmsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final alarms = snapshot.data!;
          if (alarms.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📍', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text('No location alarms', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: scheme.onSurface)),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add an alarm that\ntriggers when you arrive somewhere.\n'
                    'Alarm+ needs to stay running for it to notice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
            itemCount: alarms.length,
            itemBuilder: (context, i) {
              final alarm = alarms[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(alarm.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: scheme.onSurface)),
                          Text(
                            '${alarm.lat.toStringAsFixed(4)}, ${alarm.lng.toStringAsFixed(4)} · ${alarm.radiusMeters.round()}m radius',
                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: alarm.isEnabled,
                      onChanged: (v) => _toggle(alarm, v),
                      thumbColor: WidgetStatePropertyAll(Colors.white),
                      trackColor: WidgetStateProperty.resolveWith<Color?>((states) =>
                          states.contains(WidgetState.selected)
                              ? const Color(0xFF22C55E)
                              : scheme.outlineVariant),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                      onPressed: () => _delete(alarm),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
