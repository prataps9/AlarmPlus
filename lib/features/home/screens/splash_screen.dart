import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:alarm_plus/features/alarm/services/alarm_service.dart';
import 'package:alarm_plus/features/mascot/models/mascot_mood.dart';
import 'package:alarm_plus/features/mascot/widgets/pip_mascot.dart';

/// Launch animation: "the alarm goes off, Pip wakes up, the sun rises".
///
/// The first frame deliberately matches the Android 12+ system splash
/// (`res/drawable/splash_pip_animated.xml`): the same midnight colour and a
/// sleeping Pip at the same size and position, ringing. That way the
/// system's hand-off to Flutter looks like one continuous animation.
///
/// Tap anywhere to skip. With reduce-motion on it shows the final frame
/// briefly and moves on.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  static const routeName = '/splash';

  /// Keep in sync with `@color/splash_night` in `res/values/colors.xml`.
  static const night = Color(0xFF1A0533);

  /// Native icon: Pip's 100-unit box is drawn 1.5x in dp.
  static const nativePipSize = 150.0;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2600);

  // Timeline, as fractions of [_total].
  static const _wakeAt = 0.28;
  static const _dawn = Interval(0.26, 0.80, curve: Curves.easeInOutCubic);
  static const _rise = Interval(0.40, 0.70, curve: Curves.easeOutBack);
  static const _tagline = Interval(0.74, 0.92, curve: Curves.easeOut);

  late final AnimationController _c =
      AnimationController(vsync: this, duration: _total);
  bool _awake = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onTick);
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
      _awake = true;
      Future<void>.delayed(const Duration(milliseconds: 700), _leave);
    } else {
      _c.forward();
    }
  }

  void _onTick() {
    if (!_awake && _c.value >= _wakeAt) {
      setState(() => _awake = true);
      HapticFeedback.mediumImpact();
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
    return Scaffold(
      backgroundColor: SplashScreen.night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _leave,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final dawn = _dawn.transform(t);
            final rise = _rise.transform(t);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: SkyPainter(dawn: dawn, time: t)),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -70 * rise),
                    child: Transform.scale(
                      scale: 1 - 0.12 * rise,
                      child: PipMascot(
                        size: SplashScreen.nativePipSize,
                        mood: _awake ? MascotMood.cheering : MascotMood.sleepy,
                        ringing: !_awake,
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0, 0.42),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Wordmark(t: t),
                      const SizedBox(height: 10),
                      Opacity(
                        opacity: _tagline.transform(t),
                        child: Text(
                          'Wake up. Level up.',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                            letterSpacing: 0.6,
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

/// "Alarm+" with each letter dropping in on its own elastic bounce, and the
/// "+" spinning into place last.
class _Wordmark extends StatelessWidget {
  const _Wordmark({required this.t});

  final double t;

  static const _letters = ['A', 'l', 'a', 'r', 'm', '+'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _letters.length; i++) _letter(i),
      ],
    );
  }

  Widget _letter(int i) {
    final start = 0.50 + i * 0.045;
    final e = Interval(start, math.min(1.0, start + 0.22), curve: Curves.elasticOut)
        .transform(t);
    final visible = Interval(start, start + 0.05).transform(t);
    final isPlus = _letters[i] == '+';
    return Opacity(
      opacity: visible,
      child: Transform.translate(
        offset: Offset(0, -46 * (1 - e)),
        child: Transform.rotate(
          angle: isPlus ? (1 - e) * math.pi : 0,
          child: Text(
            _letters[i],
            style: GoogleFonts.spaceGrotesk(
              fontSize: 46,
              fontWeight: FontWeight.w800,
              color: isPlus ? const Color(0xFFFDE68A) : Colors.white,
              height: 1,
              shadows: const [
                Shadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Night sky turning into sunrise: a gradient that warms from midnight,
/// stars that twinkle then fade, and a glowing sun coming over the horizon.
@visibleForTesting
class SkyPainter extends CustomPainter {
  SkyPainter({required this.dawn, required this.time});

  /// 0 = midnight (flat [SplashScreen.night], matching the system splash),
  /// 1 = full sunrise.
  final double dawn;

  /// Overall animation time, drives the twinkle.
  final double time;

  static const _nightTop = SplashScreen.night;
  static const _nightBottom = SplashScreen.night;
  static const _dawnTop = Color(0xFF4C1D95);
  static const _dawnMid = Color(0xFFDB2777);
  static const _dawnBottom = Color(0xFFF59E0B);

  // Deterministic star field, as fractions of the screen.
  static final List<Offset> _stars = List.generate(36, (i) {
    final r = math.Random(i * 7919);
    return Offset(r.nextDouble(), r.nextDouble() * 0.65);
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(_nightTop, _dawnTop, dawn)!,
            Color.lerp(_nightBottom, _dawnMid, dawn)!,
            Color.lerp(_nightBottom, _dawnBottom, dawn)!,
          ],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );

    // Stars: fade in over the first moments (the native splash has none),
    // twinkle, then disappear as the sky brightens.
    final starAlpha = (time / 0.12).clamp(0.0, 1.0) * (1 - dawn);
    if (starAlpha > 0.01) {
      for (var i = 0; i < _stars.length; i++) {
        final twinkle = 0.55 + 0.45 * math.sin(time * 18 + i * 1.7);
        canvas.drawCircle(
          Offset(_stars[i].dx * size.width, _stars[i].dy * size.height),
          i % 5 == 0 ? 1.8 : 1.1,
          Paint()..color = Colors.white.withValues(alpha: starAlpha * twinkle),
        );
      }
    }

    // Sun rising from below the bottom edge, with a soft glow.
    if (dawn > 0) {
      // Ends with ~3/4 of the disc showing, well below the tagline.
      final radius = size.width * 0.36;
      final center = Offset(
        size.width / 2,
        size.height + radius - radius * 0.75 * dawn,
      );
      canvas.drawCircle(
        center,
        radius * 1.9,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFDE68A).withValues(alpha: 0.55 * dawn),
            const Color(0xFFFDE68A).withValues(alpha: 0),
          ]).createShader(Rect.fromCircle(center: center, radius: radius * 1.9)),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFFEF3C7).withValues(alpha: 0.9 * dawn),
      );
    }
  }

  @override
  bool shouldRepaint(SkyPainter old) => old.dawn != dawn || old.time != time;
}
