import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/splash';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _iconOpacity;
  late final Animation<double> _iconScale;
  late final Animation<double> _iconShrink;
  late final Animation<double> _textContainerOpacity;

  bool _showText = false;

  @override
  void initState() {
    super.initState();
    AlarmService.requestPermissions();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    // Phase 1: Icon fades in + scales up (0-800ms => 0.0-0.44)
    _iconOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.30, curve: Curves.easeIn),
    );

    _iconScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.44, curve: Curves.easeOutBack),
      ),
    );

    // Phase 2: Icon shrinks slightly as text appears (0.44-0.72 => 800-1300ms)
    _iconShrink = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.44, 0.72, curve: Curves.easeInOutCubic),
      ),
    );

    // Phase 2: Text container fades in (0.50-0.72 => 900-1300ms)
    _textContainerOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.50, 0.72, curve: Curves.easeIn),
    );

    _controller.addListener(() {
      if (_controller.value >= 0.50 && !_showText) {
        setState(() => _showText = true);
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTextFinished() {
    Future.delayed(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      final prefs = await SharedPreferences.getInstance();
      final done = prefs.getBool('onboarding_complete') ?? false;
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(done ? '/app' : '/onboarding');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Opacity(
                  opacity: _iconOpacity.value,
                  child: Transform.scale(
                    scale: _iconScale.value * _iconShrink.value,
                    child: const Icon(
                      Icons.alarm_rounded,
                      size: 80,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_showText) ...[
                  const SizedBox(width: 14),
                  Opacity(
                    opacity: _textContainerOpacity.value,
                    child: AnimatedTextKit(
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Alarm+',
                          textStyle: GoogleFonts.spaceGrotesk(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: 1.5,
                          ),
                          speed: const Duration(milliseconds: 120),
                          cursor: '|',
                        ),
                      ],
                      totalRepeatCount: 1,
                      displayFullTextOnTap: false,
                      onFinished: _onTextFinished,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
