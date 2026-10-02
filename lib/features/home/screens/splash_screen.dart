import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/shared/widgets/alarm_logo.dart';

/// Launch screen: white, with the Alarm+ logo.
///
/// The first frame matches the Android 12+ system splash
/// (`res/drawable/splash_logo_animated.xml`): same white, same logo at the
/// same size and position, minute hand back at 12 after its sweep. The logo
/// then glides up and the wordmark fades in beneath it, so the hand-off
/// from the system splash reads as one motion.
///
/// Tap anywhere to skip. With reduce-motion on it shows the final frame
/// briefly and moves on.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/splash';

  /// Keep in sync with `@color/splash_background` in `res/values/colors.xml`.
  static const background = Colors.white;

  /// The native splash icon canvas (240dp), which the logo fills.
  static const nativeLogoSize = 240.0;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 1500);

  static const _lift = Interval(0.10, 0.55, curve: Curves.easeOutCubic);
  static const _word = Interval(0.35, 0.75, curve: Curves.easeOut);
  static const _tagline = Interval(0.55, 0.90, curve: Curves.easeOut);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total);
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) _leave();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_c.isAnimating || _c.isCompleted) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _c.value = 1;
      Future<void>.delayed(const Duration(milliseconds: 600), _leave);
    } else {
      _c.forward();
    }
  }

  Future<void> _leave() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('onboarding_complete') ?? false;
    // Returning users: re-check permissions now that there is UI, instead
    // of popping system dialogs before the first frame. (First-run users
    // get the explained permissions page in onboarding.)
    if (done) AlarmService.requestPermissions();
    if (!mounted) return;

    replaceRouteInPlace(context, done ? '/app' : '/onboarding');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF0F172A);
    return Scaffold(
      backgroundColor: SplashScreen.background,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final lift = _lift.transform(_c.value);
            final word = _word.transform(_c.value);
            final tag = _tagline.transform(_c.value);
            return Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -64 * lift),
                    child: Transform.scale(
                      scale: 1 - 0.3 * lift,
                      child: const AlarmLogo(
                        size: SplashScreen.nativeLogoSize,
                        color: ink,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.30),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Opacity(
                        opacity: word,
                        child: Transform.translate(
                          offset: Offset(0, 12 * (1 - word)),
                          child: Text(
                            'Alarm+',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: ink,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Opacity(
                        opacity: tag,
                        child: const Text(
                          'Wake up on time, every time.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Replaces the route that owns [context] with the named route, keeping
/// anything pushed above it.
///
/// The splash can't use `pushReplacementNamed`: that replaces the *top*
/// route, and when an alarm cold-starts the app its ring screen is pushed
/// above the splash — so the ring screen was the one thrown away.
@visibleForTesting
void replaceRouteInPlace(BuildContext context, String name) {
  final app = context.findAncestorWidgetOfExactType<MaterialApp>();
  final builder = app?.routes?[name];
  final ownRoute = ModalRoute.of(context);
  if (builder == null || ownRoute == null) {
    Navigator.of(context).pushReplacementNamed(name);
    return;
  }
  Navigator.of(context).replace(
    oldRoute: ownRoute,
    newRoute: PageRouteBuilder<void>(
      settings: RouteSettings(name: name),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (context, _, _) => builder(context),
      transitionsBuilder: (context, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 1.06, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
