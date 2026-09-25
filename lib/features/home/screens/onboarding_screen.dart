import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const routeName = '/onboarding';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardingPage(
      mood: MascotMood.waving,
      title: "Hi, I'm Pip!",
      body: "I'm your wake-up buddy. My challenges (math, memory, shake, barcode and more) make sure you actually get out of bed.",
    ),
    _OnboardingPage(
      mood: MascotMood.cheering,
      title: 'Earn XP\nEvery Morning',
      body: 'Build streaks, level up, and unlock badges the faster you dismiss your alarm.',
    ),
    _OnboardingPage(
      mood: MascotMood.sleepy,
      title: 'Sleep\nSmarter',
      body: 'Track your sleep diary, set a bedtime schedule, and get weekly insights on how rested you really are.',
    ),
    _OnboardingPage(
      mood: MascotMood.worried,
      title: 'Needs a Few\nPermissions',
      body: "I can't ring without notifications and exact-alarm access. Grant them so I never miss your wake-up.",
      isPermission: true,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _grantPermissions() async {
    await AlarmService.requestPermissions();
  }

  Future<void> _finish() async {
    // No-op for anything already granted; catches users who skipped the
    // "Grant Permissions" button, since alarms can't ring without them.
    await AlarmService.requestPermissions();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/app');
    }
  }

  void _next() {
    if (_page < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: _pages.length,
                itemBuilder: (_, i) => _pages[i],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: i == _page ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: i == _page
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                  if (_pages[_page].isPermission) ...[
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _grantPermissions,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                          side: const BorderSide(color: Color(0xFF22C55E), width: 2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(40)),
                        ),
                        child: const Text('Grant Permissions',
                            style: TextStyle(
                                color: Color(0xFF22C55E),
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(40)),
                      ),
                      child: Text(
                        _page == _pages.length - 1 ? "Let's Go" : 'Next',
                        style: GoogleFonts.spaceGrotesk(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.mood,
    required this.title,
    required this.body,
    this.isPermission = false,
  });

  final MascotMood mood;
  final String title;
  final String body;
  final bool isPermission;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PipMascot(mood: mood, size: 128),
          const SizedBox(height: 28),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: const TextStyle(
              fontSize: 17,
              color: Color(0xFF475569),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
