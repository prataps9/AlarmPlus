import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:alarm_plus/core/theme/app_theme.dart';
import 'package:alarm_plus/core/theme/app_tokens.dart';
import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/alarm/screens/alarms_screen.dart';
import 'package:alarm_plus/features/alarm/services/alarm_providers.dart';
import 'package:alarm_plus/features/alarm/services/alarm_ring_flow.dart';
import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';
import 'package:alarm_plus/features/home/screens/home_screen.dart';
import 'package:alarm_plus/features/home/screens/insights_screen.dart';
import 'package:alarm_plus/features/home/screens/splash_screen.dart';
import 'package:alarm_plus/features/home/screens/onboarding_screen.dart';
import 'package:alarm_plus/features/location/screens/location_alarm_screen.dart';
import 'package:alarm_plus/features/location/screens/location_picker_screen.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';
import 'package:alarm_plus/features/progress/screens/quests_screen.dart';
import 'package:alarm_plus/features/settings/screens/settings_screen.dart';
import 'package:alarm_plus/features/settings/screens/sound_settings_screen.dart';
import 'package:alarm_plus/features/sleep/screens/bedtime_setup_screen.dart';
import 'package:alarm_plus/features/sleep/screens/morning_check_in_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_diary_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_sounds_screen.dart';
import 'package:alarm_plus/features/sleep/screens/wake_routine_screen.dart';
import 'package:alarm_plus/features/sleep/screens/wind_down_screen.dart';
import 'package:alarm_plus/core/services/storage_service.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/core/services/widget_command_service.dart';
import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/shared/widgets/celebration_overlay_host.dart';
import 'package:alarm_plus/shared/widgets/live_status_island.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await AlarmService.init();
  await AlarmService.restoreEnabledAlarms();
  await WidgetSyncService.refresh();
  await StreakReminderService.refresh();
  await AlarmRingFlow.bindNativeAlarmEvents();
  WidgetCommandService.bind();
  await WidgetCommandService.drainPending();
  await NapService.checkMissedNap();
  await LocationAlarmService.startMonitoring();
  runApp(const AlarmPlusApp());
}

class AlarmPlusApp extends StatelessWidget {
  const AlarmPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _AppWithTheme(),
    );
  }
}

class _AppWithTheme extends ConsumerStatefulWidget {
  const _AppWithTheme();

  @override
  ConsumerState<_AppWithTheme> createState() => _AppWithThemeState();
}

class _AppWithThemeState extends ConsumerState<_AppWithTheme>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A repeating alarm only re-arms its next occurrence when it's dismissed
    // in-app. Resuming is the reliable moment to notice a chain that broke
    // while we weren't running.
    if (state == AppLifecycleState.resumed) {
      unawaited(AlarmService.resyncSchedules());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeDarkProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Alarm+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) => CelebrationOverlayHost(
        child: LiveStatusIsland(child: child ?? const SizedBox.shrink()),
      ),
      routes: {
          '/': (_) => const SplashScreen(),
          '/app': (_) => const MainScaffold(),
          OnboardingScreen.routeName: (_) => const OnboardingScreen(),
          FocusTimerScreen.routeName: (_) => const FocusTimerScreen(),
          AlarmRingScreen.routeName: (_) => const AlarmRingScreen(),
          AlarmsScreen.routeName: (_) => const AlarmsScreen(),
          MorningMissionsScreen.routeName: (_) => const MorningMissionsScreen(),
          QuestsScreen.routeName: (_) => const QuestsScreen(),
          SplashScreen.routeName: (_) => const SplashScreen(),
          WakeRoutineScreen.routeName: (_) => const WakeRoutineScreen(),
          SleepInsightsScreen.routeName: (_) => const SleepInsightsScreen(),
          BedtimeSetupScreen.routeName: (_) => const BedtimeSetupScreen(),
          WindDownScreen.routeName: (_) => const WindDownScreen(),
          LocationAlarmScreen.routeName: (_) => const LocationAlarmScreen(),
          LocationPickerScreen.routeName: (_) => const LocationPickerScreen(),
          SleepSoundsScreen.routeName: (_) => const SleepSoundsScreen(),
          SleepDiaryScreen.routeName: (_) => const SleepDiaryScreen(),
          MorningCheckInScreen.routeName: (_) => const MorningCheckInScreen(),
          NapTimerScreen.routeName: (_) => const NapTimerScreen(),
          SoundSettingsScreen.routeName: (_) => const SoundSettingsScreen(),
        },
    );
  }
}

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  static const _destinations = [
    (icon: Icons.alarm_rounded, label: 'ALARMS'),
    (icon: Icons.insights_rounded, label: 'INSIGHTS'),
    (icon: Icons.settings_rounded, label: 'SETTINGS'),
  ];

  static bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    final isDesktopPlatform = platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    return isDesktopPlatform || MediaQuery.of(context).size.width >= 720;
  }

  void _onTabSelected(WidgetRef ref, int index) {
    if (ref.read(currentTabIndexProvider) == index) return;
    HapticFeedback.selectionClick();
    ref.read(currentTabIndexProvider.notifier).state = index;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);

    // IndexedStack keeps each tab alive across switches. Previously the tabs
    // were indexed out of a list, so every switch rebuilt the screen from
    // scratch and re-ran its data loads.
    final body = IndexedStack(
      index: currentTabIndex,
      children: const [
        HomeScreen(),
        InsightsScreen(),
        SettingsScreen(),
      ],
    );

    if (_isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentTabIndex,
              onDestinationSelected: (index) => _onTabSelected(ref, index),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(0, Spacing.xl, 0, Spacing.xxl),
                child: Text(
                  'Alarm+',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              destinations: [
                for (final d in _destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentTabIndex,
        onDestinationSelected: (index) => _onTabSelected(ref, index),
        destinations: [
          for (final d in _destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}
