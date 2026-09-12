import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:alarm_plus/features/location/models/location_alarm.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';

class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  static const routeName = '/location-picker';

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _pinned;
  double _radius = 200;
  final _labelController = TextEditingController();
  final _mapController = MapController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _goToCurrentLocation();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    try {
      final granted = await LocationAlarmService.requestPermission();
      if (!granted) {
        setState(() => _loading = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      final here = LatLng(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _pinned = here;
        _loading = false;
      });
      _mapController.move(here, 15);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_pinned == null) return;
    final label = _labelController.text.trim().isEmpty ? 'Location Alarm' : _labelController.text.trim();
    final alarm = LocationAlarm(
      id: LocationAlarmService.generateId(),
      label: label,
      lat: _pinned!.latitude,
      lng: _pinned!.longitude,
      radiusMeters: _radius,
    );
    await LocationAlarmService.save(alarm);
    await LocationAlarmService.startMonitoring();
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'PICK LOCATION',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 3, color: Color(0xFF64748B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_pinned != null)
            TextButton(
              onPressed: _save,
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _pinned ?? const LatLng(0, 0),
                      initialZoom: 15,
                      onTap: (_, latlng) => setState(() => _pinned = latlng),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.alarmplus.app',
                      ),
                      if (_pinned != null) ...[
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _pinned!,
                              radius: _radius,
                              useRadiusInMeter: true,
                              color: const Color(0xFF22C55E).withValues(alpha: 0.2),
                              borderColor: const Color(0xFF22C55E),
                              borderStrokeWidth: 2,
                            ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _pinned!,
                              child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 36),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, -4))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_pinned == null)
                  const Text('Tap on the map to drop a pin', style: TextStyle(color: Color(0xFF94A3B8)))
                else
                  Text(
                    '${_pinned!.latitude.toStringAsFixed(5)}, ${_pinned!.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _labelController,
                  decoration: InputDecoration(
                    hintText: 'Label (e.g. Home, Office)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Trigger radius: ${_radius.round()}m'),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  activeColor: const Color(0xFF22C55E),
                  onChanged: (v) => setState(() => _radius = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
