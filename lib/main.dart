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
import 'package:alarm_plus/features/clock/screens/world_clock_screen.dart';
import 'package:alarm_plus/features/clock/services/clock_service.dart';
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
import 'package:alarm_plus/features/settings/screens/alarm_health_screen.dart';
import 'package:alarm_plus/features/settings/screens/settings_screen.dart';
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
  // on someone's phone costs that feature, never the whole app. Only what
  // the first frame (or a ringing alarm that launched the app) needs runs
  // before runApp; the rest follows the first frame.
  await runStartupStep('storage', StorageService.init);
  await runStartupStep('settings', AppSettings.load);
  // Independent of each other, so they overlap instead of adding up.
  await Future.wait([
    runStartupStep('premium', PremiumService.init),
    runStartupStep('mascot', MascotService.init),
    runStartupStep('alarm engine', AlarmService.init),
  ]);
  await runStartupStep('restore alarms', AlarmService.restoreEnabledAlarms);
  // Bound early so a ring event that launched the app isn't missed.
  await runStartupStep('ring events', AlarmRingFlow.bindNativeAlarmEvents);
  await runStartupStep('widget commands', () async {
    WidgetCommandService.bind();
    await WidgetCommandService.drainPending();
  });
  await runStartupStep('system events', BackgroundTasks.bindForegroundHandlers);
  runApp(const AlarmPlusApp());
  unawaited(_afterFirstFrame());
}

/// Work nothing on screen waits for: widget and reminder refreshes, the
/// location monitor, shortcuts. Running it after the first frame gets the
/// app on screen noticeably sooner.
Future<void> _afterFirstFrame() async {
  await WidgetsBinding.instance.endOfFrame;
  await runStartupStep('retired timer', ClockService.clearRetiredTimer);
  await runStartupStep('widget sync', WidgetSyncService.refresh);
  await runStartupStep('streak reminder', StreakReminderService.refresh);
  await runStartupStep('missed nap', NapService.checkMissedNap);
  await runStartupStep('location alarms', LocationAlarmService.startMonitoring);
  await runStartupStep('shortcuts', AppShortcutsService.init);
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
          AlarmHealthScreen.routeName: (_) => const AlarmHealthScreen(),
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Order must match AppTab.
  static const _destinations = [
    (icon: Icons.alarm_outlined, selected: Icons.alarm_rounded, label: 'Alarm'),
    (icon: Icons.public_outlined, selected: Icons.public_rounded, label: 'Clock'),
    (icon: Icons.insights_outlined, selected: Icons.insights_rounded, label: 'Insights'),
    (icon: Icons.settings_outlined, selected: Icons.settings_rounded, label: 'Settings'),
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
    // The tabs stay alive, so without this Insights kept showing the numbers
    // from before this morning's alarm.
    if (index == AppTab.insights) ref.invalidate(insightsSummaryProvider);
  }

  @override
  Widget build(BuildContext context) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);

    // Tabs stay alive across switches (no rebuilding, no re-running their
    // data loads) but are only built the first time they are opened, so
    // launch builds one screen instead of four.
    final body = _LazyTabs(
      index: currentTabIndex,
      builders: const [
        _tab0,
        _tab1,
        _tab2,
        _tab3,
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
                    selectedIcon: Icon(d.selected),
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
              selectedIcon: Icon(d.selected),
              label: d.label,
            ),
        ],
      ),
    );
  }

  static Widget _tab0(BuildContext _) => const HomeScreen();
  static Widget _tab1(BuildContext _) => const WorldClockScreen();
  static Widget _tab2(BuildContext _) => const InsightsScreen();
  static Widget _tab3(BuildContext _) => const SettingsScreen();
}

/// An [IndexedStack] that builds each tab the first time it is shown and
/// fades the new tab in (reduced to nothing when the system asks for less
/// motion). Built tabs keep their state while hidden.
class _LazyTabs extends StatefulWidget {
  const _LazyTabs({required this.index, required this.builders});

  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<_LazyTabs> createState() => _LazyTabsState();
}

class _LazyTabsState extends State<_LazyTabs>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _fade, curve: Curves.easeOutCubic);
  late final Set<int> _built = {widget.index};

  @override
  void didUpdateWidget(_LazyTabs old) {
    super.didUpdateWidget(old);
    if (old.index == widget.index) return;
    _built.add(widget.index);
    if (!MediaQuery.disableAnimationsOf(context)) _fade.forward(from: 0);
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1).animate(_curve),
        child: IndexedStack(
          index: widget.index,
          children: [
            for (var i = 0; i < widget.builders.length; i++)
              // Each tab repaints on its own: the per-second clocks on one
              // never repaint the others.
              _built.contains(i)
                  ? RepaintBoundary(child: widget.builders[i](context))
                  : const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}
