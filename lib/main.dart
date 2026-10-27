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
import 'package:alarm_plus/features/clock/screens/stopwatch_screen.dart';
import 'package:alarm_plus/features/clock/screens/timer_screen.dart';
import 'package:alarm_plus/features/clock/screens/world_clock_screen.dart';
import 'package:alarm_plus/features/focus/screens/focus_timer_screen.dart';
import 'package:alarm_plus/features/focus/screens/nap_timer_screen.dart';
import 'package:alarm_plus/features/focus/services/nap_service.dart';
import 'package:alarm_plus/features/home/providers/insights_providers.dart';
import 'package:alarm_plus/features/home/screens/home_screen.dart';
import 'package:alarm_plus/features/home/screens/insights_screen.dart';
import 'package:alarm_plus/features/home/screens/splash_screen.dart';
import 'package:alarm_plus/features/home/screens/onboarding_screen.dart';
import 'package:alarm_plus/features/location/screens/location_alarm_screen.dart';
import 'package:alarm_plus/features/mascot/screens/wardrobe_screen.dart';
import 'package:alarm_plus/features/mascot/services/mascot_service.dart';
import 'package:alarm_plus/features/location/screens/location_picker_screen.dart';
import 'package:alarm_plus/features/location/services/location_alarm_service.dart';
import 'package:alarm_plus/features/missions/screens/morning_missions_screen.dart';
import 'package:alarm_plus/features/settings/screens/sound_settings_screen.dart';
import 'package:alarm_plus/features/sleep/screens/bedtime_setup_screen.dart';
import 'package:alarm_plus/features/sleep/screens/morning_check_in_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_diary_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_insights_screen.dart';
import 'package:alarm_plus/features/sleep/screens/sleep_sounds_screen.dart';
import 'package:alarm_plus/features/sleep/screens/wake_routine_screen.dart';
import 'package:alarm_plus/features/sleep/screens/wind_down_screen.dart';
import 'package:alarm_plus/core/services/app_settings.dart';
import 'package:alarm_plus/core/services/app_shortcuts_service.dart';
import 'package:alarm_plus/core/services/premium_service.dart';
import 'package:alarm_plus/core/services/storage_service.dart';
import 'package:alarm_plus/core/background_tasks.dart';
import 'package:alarm_plus/core/startup.dart';
import 'package:alarm_plus/core/services/streak_reminder_service.dart';
import 'package:alarm_plus/core/services/widget_command_service.dart';
import 'package:alarm_plus/core/services/widget_sync_service.dart';
import 'package:alarm_plus/shared/widgets/celebration_overlay_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every step is isolated (see runStartupStep): a plugin that fails or hangs
  // on someone's phone costs that feature, never the whole app. Order matters
  // only where noted.
  await runStartupStep('storage', StorageService.init);
  await runStartupStep('settings', AppSettings.load);
  await runStartupStep('premium', PremiumService.init);
  await runStartupStep('mascot', MascotService.init);
  await runStartupStep('alarm engine', AlarmService.init);
  await runStartupStep('restore alarms', AlarmService.restoreEnabledAlarms);
  await runStartupStep('widget sync', WidgetSyncService.refresh);
  await runStartupStep('streak reminder', StreakReminderService.refresh);
  // Bound early so a ring event that launched the app isn't missed.
  await runStartupStep('ring events', AlarmRingFlow.bindNativeAlarmEvents);
  await runStartupStep('widget commands', () async {
    WidgetCommandService.bind();
    await WidgetCommandService.drainPending();
  });
  await runStartupStep('system events', BackgroundTasks.bindForegroundHandlers);
  await runStartupStep('missed nap', NapService.checkMissedNap);
  await runStartupStep('location alarms', LocationAlarmService.startMonitoring);
  await runStartupStep('shortcuts', AppShortcutsService.init);
  runApp(const AlarmPlusApp());
}

/// Started by Android (BackgroundDartRunner) for a timezone change or a
/// location arrival while the app is closed. No UI.
@pragma('vm:entry-point')
Future<void> backgroundMain(List<String> args) => BackgroundTasks.runTask(args);

class AlarmPlusApp extends StatelessWidget {
  const AlarmPlusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(
      child: _AppWithTheme(),
    );
  }
}

class _AppWithTheme extends ConsumerWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Alarm+',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      builder: (context, child) =>
          CelebrationOverlayHost(child: child ?? const SizedBox.shrink()),
      routes: {
          '/': (_) => const SplashScreen(),
          '/app': (_) => const MainScaffold(),
          OnboardingScreen.routeName: (_) => const OnboardingScreen(),
          FocusTimerScreen.routeName: (_) => const FocusTimerScreen(),
          AlarmRingScreen.routeName: (_) => const AlarmRingScreen(),
          AlarmsScreen.routeName: (_) => const AlarmsScreen(),
          MorningMissionsScreen.routeName: (_) => const MorningMissionsScreen(),
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
          WardrobeScreen.routeName: (_) => const WardrobeScreen(),
        },
    );
  }
}

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _openRequests;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(BackgroundTasks.followTimezone());
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tapping "Time's up" opens the Timer tab, on top of whatever was open.
    _openRequests = AlarmService.openRequests.listen((what) {
      if (what != 'timer' || !mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst || r.settings.name == '/app');
      ref.read(currentTabIndexProvider.notifier).state = AppTab.timer;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _openRequests?.cancel();
    super.dispose();
  }

  // Order must match AppTab. Settings is behind the gear on the Alarm tab,
  // as in the stock clock app.
  static const _destinations = [
    (icon: Icons.alarm_rounded, label: 'Alarm'),
    (icon: Icons.public_rounded, label: 'Clock'),
    (icon: Icons.hourglass_bottom_rounded, label: 'Timer'),
    (icon: Icons.timer_outlined, label: 'Stopwatch'),
    (icon: Icons.insights_rounded, label: 'Insights'),
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
    // The IndexedStack keeps Insights alive, so without this it kept
    // showing the numbers from before this morning's alarm.
    if (index == AppTab.insights) ref.invalidate(insightsSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);

    // IndexedStack keeps each tab alive across switches. Previously the tabs
    // were indexed out of a list, so every switch rebuilt the screen from
    // scratch and re-ran its data loads.
    final body = IndexedStack(
      index: currentTabIndex,
      children: const [
        HomeScreen(),
        WorldClockScreen(),
        TimerScreen(),
        StopwatchScreen(),
        InsightsScreen(),
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
