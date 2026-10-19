import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The moon's phase, worked out from the date. The moon goes from new to
/// full and back every 29.53 days, so counting days since a known new moon
/// tells us where it is in that cycle.
class MoonPhase {
  /// Days since the last new moon, 0 to about 29.5.
  final double age;

  const MoonPhase(this.age);

  static const synodicMonth = 29.530588853;

  factory MoonPhase.at(DateTime when) {
    // A new moon happened on 6 January 2000 at 18:14 UTC.
    final knownNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final days = when.toUtc().difference(knownNewMoon).inMinutes / (60 * 24);
    final age = days % synodicMonth;
    return MoonPhase(age < 0 ? age + synodicMonth : age);
  }

  /// How much of the moon is lit, 0 (new) to 1 (full).
  double get illumination => (1 - math.cos(2 * math.pi * age / synodicMonth)) / 2;

  bool get waxing => age < synodicMonth / 2;

  String get name {
    const step = 29.530588853 / 16;
    if (age < step || age >= 15 * step) return 'New moon';
    if (age < 3 * step) return 'Waxing crescent';
    if (age < 5 * step) return 'First quarter';
    if (age < 7 * step) return 'Waxing gibbous';
    if (age < 9 * step) return 'Full moon';
    if (age < 11 * step) return 'Waning gibbous';
    if (age < 13 * step) return 'Last quarter';
    return 'Waning crescent';
  }
}

/// Draws the moon with the right amount lit, as seen from the northern
/// hemisphere (lit on the right while waxing).
class MoonPicture extends StatelessWidget {
  const MoonPicture({super.key, required this.phase, this.size = 22, this.darkColor});

  final MoonPhase phase;
  final double size;
  final Color? darkColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _MoonPainter(
        phase: phase,
        dark: darkColor ?? Colors.white.withValues(alpha: 0.18),
      ),
    );
  }
}

class _MoonPainter extends CustomPainter {
  _MoonPainter({required this.phase, required this.dark});

  final MoonPhase phase;
  final Color dark;

  static const _lit = Color(0xFFF3EEDC);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, r, Paint()..color = dark);

    // The terminator (the line between light and dark) is half an ellipse.
    // Its width depends on the phase: wide at new and full, flat at quarters.
    final k = math.cos(2 * math.pi * phase.age / MoonPhase.synodicMonth);
    final ellipse = Rect.fromCenter(center: c, width: 2 * r * k.abs(), height: 2 * r);
    final circle = Rect.fromCircle(center: c, radius: r);
    final waxing = phase.waxing;

    final path = Path()..moveTo(c.dx, c.dy - r);
    // The lit half of the disc: right side while waxing, left while waning.
    path.arcTo(circle, -math.pi / 2, waxing ? math.pi : -math.pi, false);
    // Back to the top along the terminator.
    final sweep = waxing ? (k > 0 ? -math.pi : math.pi) : (k > 0 ? math.pi : -math.pi);
    path.arcTo(ellipse, math.pi / 2, sweep, false);
    path.close();

    canvas.drawPath(path, Paint()..color = _lit);
  }

  @override
  bool shouldRepaint(_MoonPainter old) => old.phase.age != phase.age || old.dark != dark;
}
