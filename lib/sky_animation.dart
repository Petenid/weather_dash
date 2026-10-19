import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'settings.dart';
import 'theme.dart';

/// Gentle motion in the sky that matches the weather: rain, snow, drifting
/// clouds, twinkling stars. It holds still (showing a still picture) when:
/// - animations are turned off in the system's accessibility settings,
/// - power saver is on in Weather Dash's settings, or
/// - Weather Dash is in the background and "pause in background" is on.
class SkyAnimation extends StatefulWidget {
  const SkyAnimation({super.key, required this.weatherCode, required this.isDay});

  final int weatherCode;
  final bool isDay;

  @override
  State<SkyAnimation> createState() => _SkyAnimationState();
}

class _SkyAnimationState extends State<SkyAnimation> with SingleTickerProviderStateMixin {
  // Runs from 0 to 1 over a minute, over and over. The painter turns it into
  // seconds, so everything moves at a steady speed.
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void initState() {
    super.initState();
    settings.addListener(_update);
    appInForeground.addListener(_update);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _update();
  }

  @override
  void dispose() {
    settings.removeListener(_update);
    appInForeground.removeListener(_update);
    _clock.dispose();
    super.dispose();
  }

  bool get _still {
    final s = settings.value;
    return MediaQuery.of(context).disableAnimations ||
        s.powerSaver ||
        (s.pauseInBackground && !appInForeground.value);
  }

  /// Starts or stops the clock to match the settings and window state.
  void _update() {
    if (!mounted) return;
    final still = _still;
    if (still && _clock.isAnimating) {
      _clock.stop(); // Freezes where it is, rather than jumping back.
    } else if (!still && !_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SkyPainter(
            clock: _clock,
            kind: skyKindFor(widget.weatherCode),
            isDay: widget.isDay,
            stormy: widget.weatherCode >= 95,
            still: MediaQuery.of(context).disableAnimations || settings.value.powerSaver,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// One raindrop, snowflake, star or cloud. Positions are fractions of the
/// sky's width and height, so they fit any window size.
class _Particle {
  final double x, y, speed, size, phase, alpha;
  const _Particle(this.x, this.y, this.speed, this.size, this.phase, this.alpha);
}

List<_Particle> _particles(int count, int seed) {
  final r = math.Random(seed); // A fixed seed: the same sky every time.
  return [
    for (var i = 0; i < count; i++)
      _Particle(r.nextDouble(), r.nextDouble(), r.nextDouble(), r.nextDouble(),
          r.nextDouble() * math.pi * 2, r.nextDouble()),
  ];
}

final _rain = _particles(120, 1);
final _snow = _particles(90, 2);
final _stars = _particles(80, 3);
final _clouds = _particles(6, 4);

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.clock,
    required this.kind,
    required this.isDay,
    required this.stormy,
    required this.still,
  }) : super(repaint: clock);

  final Animation<double> clock;
  final SkyKind kind;
  final bool isDay;
  final bool stormy;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final t = still ? 0.0 : clock.value * 60; // Seconds.

    switch (kind) {
      case SkyKind.clear:
        if (isDay) {
          _sunGlow(canvas, size);
        } else {
          _starField(canvas, size, t);
        }
      case SkyKind.partly:
        if (!isDay) _starField(canvas, size, t, density: 0.5);
        _cloudLayer(canvas, size, t, alpha: 0.10, count: 4);
      case SkyKind.overcast:
        _cloudLayer(canvas, size, t, alpha: 0.08, count: 6);
      case SkyKind.fog:
        _fogBands(canvas, size, t);
      case SkyKind.rain:
        _cloudLayer(canvas, size, t, alpha: 0.06, count: 6);
        _rainfall(canvas, size, t);
      case SkyKind.storm:
        _cloudLayer(canvas, size, t, alpha: 0.06, count: 6);
        _rainfall(canvas, size, t);
        if (stormy && !still) _lightning(canvas, size, t);
      case SkyKind.snow:
        _cloudLayer(canvas, size, t, alpha: 0.06, count: 5);
        _snowfall(canvas, size, t);
    }
  }

  void _sunGlow(Canvas canvas, Size size) {
    final centre = Offset(size.width * 0.85, size.height * 0.05);
    final radius = size.shortestSide * 0.9;
    canvas.drawCircle(
      centre,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE6A6).withValues(alpha: 0.28),
            const Color(0xFFFFE6A6).withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: centre, radius: radius)),
    );
  }

  void _starField(Canvas canvas, Size size, double t, {double density = 1}) {
    final paint = Paint()..color = Colors.white;
    final count = (_stars.length * density).round();
    for (var i = 0; i < count; i++) {
      final s = _stars[i];
      // Each star brightens and dims on its own slow rhythm.
      final twinkle = 0.55 + 0.45 * math.sin(t * (0.6 + s.speed) + s.phase);
      paint.color = Colors.white.withValues(alpha: (0.25 + 0.55 * s.alpha) * twinkle);
      canvas.drawCircle(
        Offset(s.x * size.width, s.y * size.height * 0.75),
        0.6 + s.size * 0.9,
        paint,
      );
    }
  }

  void _cloudLayer(Canvas canvas, Size size, double t, {required double alpha, required int count}) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    for (var i = 0; i < count; i++) {
      final c = _clouds[i];
      final cloudWidth = size.width * (0.25 + 0.2 * c.size);
      // Drift slowly to the right, wrapping around to the left edge.
      final span = size.width + cloudWidth * 2;
      final x = (c.x * span + t * (6 + 10 * c.speed)) % span - cloudWidth;
      final y = size.height * (0.08 + 0.55 * c.y);
      // A cloud is a few overlapping blurred circles.
      for (var j = 0; j < 4; j++) {
        final dx = cloudWidth * (j / 3 - 0.5) * 0.9;
        final r = cloudWidth * (j == 1 || j == 2 ? 0.28 : 0.2);
        canvas.drawCircle(Offset(x + cloudWidth / 2 + dx, y - (j == 1 || j == 2 ? r * 0.3 : 0)), r, paint);
      }
    }
  }

  void _fogBands(Canvas canvas, Size size, double t) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    for (var i = 0; i < 5; i++) {
      final y = size.height * (0.2 + i * 0.16);
      final shift = math.sin(t * 0.08 + i) * size.width * 0.08;
      paint.color = Colors.white.withValues(alpha: 0.07 + 0.02 * (i % 2));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(-size.width * 0.1 + shift, y, size.width * 1.2, size.height * 0.08),
          const Radius.circular(40),
        ),
        paint,
      );
    }
  }

  void _rainfall(Canvas canvas, Size size, double t) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    for (final d in _rain) {
      final fall = 0.9 + 0.6 * d.speed; // Sky heights per second.
      final y = ((d.y + t * fall) % 1.15 - 0.1) * size.height;
      final x = d.x * size.width + y * 0.12; // A slight slant, as if windy.
      final length = 12 + 12 * d.size;
      paint.color = Colors.white.withValues(alpha: 0.18 + 0.25 * d.alpha);
      canvas.drawLine(Offset(x, y), Offset(x - length * 0.12, y - length), paint);
    }
  }

  void _snowfall(Canvas canvas, Size size, double t) {
    final paint = Paint();
    for (final f in _snow) {
      final fall = 0.05 + 0.08 * f.speed;
      final y = ((f.y + t * fall) % 1.1 - 0.05) * size.height;
      final sway = math.sin(t * (0.5 + f.speed) + f.phase) * 12;
      paint.color = Colors.white.withValues(alpha: 0.45 + 0.4 * f.alpha);
      canvas.drawCircle(Offset(f.x * size.width + sway, y), 1.2 + 2 * f.size, paint);
    }
  }

  void _lightning(Canvas canvas, Size size, double t) {
    // A brief, soft flash about every 9 seconds.
    final inCycle = t % 9;
    if (inCycle > 0.18) return;
    final strength = inCycle < 0.06 || inCycle > 0.12 ? 0.10 : 0.05;
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: strength),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.kind != kind || old.isDay != isDay || old.still != still || old.stormy != stormy;
}
