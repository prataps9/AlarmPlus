import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:alarm_plus/features/alarm/screens/alarm_ring_screen.dart';
import 'package:alarm_plus/features/alarm/screens/quest_builder_screen.dart';
import 'package:alarm_plus/features/alarm/screens/qr_spot_setup_screen.dart';
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
import 'package:alarm_plus/shared/widgets/celebration_overlay_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await AlarmService.init();
  await AlarmService.restoreEnabledAlarms();
  await AlarmRingFlow.bindNativeAlarmEvents();
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

class _AppWithTheme extends ConsumerWidget {
  const _AppWithTheme();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(themeDarkProvider);
    final baseTextTheme = GoogleFonts.dmSansTextTheme();

    final lightTheme = ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        surface: Colors.white,
        primary: Color(0xFF22C55E),
        secondary: Color(0xFF94A3B8),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 44,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F172A),
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF0F172A),
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 16,
          color: const Color(0xFF334155),
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 13,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
      ),
    );

    final darkTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      colorScheme: const ColorScheme.dark(
        surface: Color(0xFF1E293B),
        primary: Color(0xFF22C55E),
        secondary: Color(0xFF94A3B8),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          fontSize: 44,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          fontSize: 30,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 16,
          color: const Color(0xFFCBD5E1),
        ),
        bodySmall: GoogleFonts.dmSans(
          fontSize: 13,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF94A3B8),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        elevation: 0,
        surfaceTintColor: Color(0xFF0F172A),
      ),
    );

    return MaterialApp(
      navigatorKey: appNavigatorKey,
      title: 'Alarm+',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) =>
          CelebrationOverlayHost(child: child ?? const SizedBox.shrink()),
      routes: {
          '/': (_) => const SplashScreen(),
          '/app': (_) => const MainScaffold(),
          OnboardingScreen.routeName: (_) => const OnboardingScreen(),
          FocusTimerScreen.routeName: (_) => const FocusTimerScreen(),
          AlarmRingScreen.routeName: (_) => const AlarmRingScreen(),
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
          QrSpotSetupScreen.routeName: (_) => const QrSpotSetupScreen(),
          QuestBuilderScreen.routeName: (_) => const QuestBuilderScreen(),
        },
    );
  }
}

class MainScaffold extends ConsumerWidget {
  const MainScaffold({super.key});

  static bool _isDesktop(BuildContext context) {
    if (kIsWeb) return false;
    final platform = defaultTargetPlatform;
    final isDesktopPlatform = platform == TargetPlatform.windows ||
        platform == TargetPlatform.macOS ||
        platform == TargetPlatform.linux;
    return isDesktopPlatform || MediaQuery.of(context).size.width >= 720;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTabIndex = ref.watch(currentTabIndexProvider);
    final isDark = ref.watch(themeDarkProvider);

    final pages = <Widget>[
      const HomeScreen(),
      const InsightsScreen(),
      const SettingsScreen(),
    ];

    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final selectedColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final unselectedColor = const Color(0xFF94A3B8);

    if (_isDesktop(context)) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: currentTabIndex,
              onDestinationSelected: (index) {
                ref.read(currentTabIndexProvider.notifier).state = index;
              },
              backgroundColor: surfaceColor,
              selectedIconTheme: IconThemeData(color: selectedColor),
              unselectedIconTheme: IconThemeData(color: unselectedColor),
              selectedLabelTextStyle: GoogleFonts.dmSans(
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                fontSize: 11,
                color: selectedColor,
              ),
              unselectedLabelTextStyle: GoogleFonts.dmSans(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                fontSize: 11,
                color: unselectedColor,
              ),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                child: Text(
                  'Alarm+',
                  style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: selectedColor,
                  ),
                ),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.alarm_rounded),
                  label: Text('ALARMS'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.insights_rounded),
                  label: Text('INSIGHTS'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_rounded),
                  label: Text('SETTINGS'),
                ),
              ],
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: pages[currentTabIndex].animate().fadeIn(
                duration: 280.ms,
                curve: Curves.easeOut,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: pages[currentTabIndex].animate().fadeIn(
        duration: 280.ms,
        curve: Curves.easeOut,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTabIndex,
        onTap: (index) {
          ref.read(currentTabIndexProvider.notifier).state = index;
        },
        selectedItemColor: selectedColor,
        unselectedItemColor: unselectedColor,
        selectedLabelStyle: GoogleFonts.dmSans(
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.dmSans(
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          fontSize: 12,
        ),
        backgroundColor: surfaceColor,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.alarm_rounded),
            label: 'ALARMS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.insights_rounded),
            label: 'INSIGHTS',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            label: 'SETTINGS',
          ),
        ],
      ),
    );
  }
}
