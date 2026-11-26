import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/core/background_tasks.dart';
import 'package:alarm_plus/core/services/native_controls.dart';
import 'package:alarm_plus/features/location/models/location_alarm.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';

const _gym = LocationAlarm(id: 'gym', label: 'Gym', lat: 51.5, lng: -0.12, radiusMeters: 150);
const _office = LocationAlarm(
    id: 'office', label: 'Office', lat: 40.7, lng: -74.0, isEnabled: false);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late List<MethodCall> nativeCalls;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    nativeCalls = [];
    messenger.setMockMethodCallHandler(NativeControls.channel, (call) async {
      nativeCalls.add(call);
      return true;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(NativeControls.channel, null));

  List<Map<String, dynamic>> lastFences() {
    final call = nativeCalls.lastWhere((c) => c.method == 'syncGeofences');
    final json = (call.arguments as Map)['fences'] as String;
    return (jsonDecode(json) as List).cast<Map<String, dynamic>>();
  }

  test('only enabled alarms become OS geofences', () {
    final fences = jsonDecode(
        LocationAlarmService.geofencePayload([_gym, _office])) as List;
    expect(fences, [
      {'id': 'gym', 'lat': 51.5, 'lng': -0.12, 'radius': 150.0},
    ]);
  });

  test('saving, switching off and deleting keep the OS geofences in step', () async {
    await LocationAlarmService.save(_gym);
    await LocationAlarmService.save(_office);
    expect(lastFences().map((f) => f['id']), ['gym']);

    await LocationAlarmService.save(_gym.copyWith(isEnabled: false));
    expect(lastFences(), isEmpty);

    await LocationAlarmService.save(_office.copyWith(isEnabled: true));
    await LocationAlarmService.delete('office');
    expect(lastFences(), isEmpty);
  });

  test('an arrival for a switched-off or deleted alarm rings nothing', () async {
    await LocationAlarmService.save(_office);
    await LocationAlarmService.handleArrivals(['office', 'gone']);
    final stored = await LocationAlarmService.loadAll();
    expect(stored.single.isEnabled, isFalse);
  });

  test('the background engine is always released, even with nothing to do', () async {
    final background = <String>[];
    const channel = MethodChannel('alarmplus/background');
    messenger.setMockMethodCallHandler(channel, (call) async {
      background.add(call.method);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await BackgroundTasks.runTask(const []);
    expect(background, ['done']);
  });
}
