import 'package:flutter/material.dart';

/// Weather Dash's look, in one place.
///
/// The screen is split like a landscape: a "sky" at the top whose colours
/// follow the real weather, and a calm "ground" below that holds the details.
/// The ground follows the Windows light/dark setting; the sky follows the
/// weather.

// Ground colours, light mode.
const _groundLight = Color(0xFFEDF1F4);
const _inkLight = Color(0xFF13202A);
const _mutedLight = Color(0xFF56656F);
const _lineLight = Color(0xFFD2DAE0);
const _panelLight = Color(0xFFE2E8EC);
const _accentLight = Color(0xFF1F67A8);

// Ground colours, dark mode.
const _groundDark = Color(0xFF10171D);
const _inkDark = Color(0xFFE4EBF0);
const _mutedDark = Color(0xFF93A3AE);
const _lineDark = Color(0xFF26323C);
const _panelDark = Color(0xFF18222A);
const _accentDark = Color(0xFF82B6E6);

/// Barlow is a typeface based on the signs along North American highways,
/// which suits a dashboard you read at a glance. Barlow Condensed is the
/// narrow cut of the same family, used for the big numbers.
const bodyFont = 'Barlow';
const numberFont = 'BarlowCondensed';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final ground = dark ? _groundDark : _groundLight;
  final ink = dark ? _inkDark : _inkLight;
  final muted = dark ? _mutedDark : _mutedLight;
  final line = dark ? _lineDark : _lineLight;
  final panel = dark ? _panelDark : _panelLight;
  final accent = dark ? _accentDark : _accentLight;

  final scheme = ColorScheme.fromSeed(
    seedColor: _accentLight,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    surface: ground,
    onSurface: ink,
    onSurfaceVariant: muted,
    outlineVariant: line,
    surfaceContainer: panel,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: ground,
  );

  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 18,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15),
    ),
    dividerTheme: DividerThemeData(color: line, space: 1, thickness: 1),
    tooltipTheme: TooltipThemeData(
      textStyle: TextStyle(fontFamily: bodyFont, color: ground, fontSize: 13),
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(6),
      ),
    ),
  );
}

/// The kinds of sky we draw.
enum SkyKind { clear, partly, overcast, fog, rain, snow, storm }

SkyKind skyKindFor(int weatherCode) {
  return switch (weatherCode) {
    0 || 1 => SkyKind.clear,
    2 => SkyKind.partly,
    3 => SkyKind.overcast,
    45 || 48 => SkyKind.fog,
    (>= 71 && <= 77) || 85 || 86 => SkyKind.snow,
    >= 51 && <= 82 => SkyKind.rain,
    >= 95 => SkyKind.storm,
    _ => SkyKind.overcast,
  };
}

/// Top and bottom colours of the sky for each kind of weather, by day and
/// by night. White text sits on all of these, so even the lightest bottom
/// colours stay dark enough to read large white type.
const Map<SkyKind, List<Color>> _daySkies = {
  SkyKind.clear: [Color(0xFF1A58A0), Color(0xFF4A8DCB)],
  SkyKind.partly: [Color(0xFF2B5E93), Color(0xFF6792BB)],
  SkyKind.overcast: [Color(0xFF4A5966), Color(0xFF76838E)],
  SkyKind.fog: [Color(0xFF59646C), Color(0xFF7B858B)],
  SkyKind.rain: [Color(0xFF30455A), Color(0xFF5A6E82)],
  SkyKind.snow: [Color(0xFF486582), Color(0xFF738DA5)],
  SkyKind.storm: [Color(0xFF242C42), Color(0xFF48526C)],
};

const Map<SkyKind, List<Color>> _nightSkies = {
  SkyKind.clear: [Color(0xFF0A142D), Color(0xFF223961)],
  SkyKind.partly: [Color(0xFF111B31), Color(0xFF2C3D5B)],
  SkyKind.overcast: [Color(0xFF192028), Color(0xFF333E49)],
  SkyKind.fog: [Color(0xFF1C2226), Color(0xFF384146)],
  SkyKind.rain: [Color(0xFF131C28), Color(0xFF2A3949)],
  SkyKind.snow: [Color(0xFF1A2636), Color(0xFF3B4E65)],
  SkyKind.storm: [Color(0xFF0E111E), Color(0xFF282C42)],
};

/// The sky shown before any weather has loaded.
const loadingSky = [Color(0xFF2B5E93), Color(0xFF6792BB)];

List<Color> skyColors(int weatherCode, {required bool isDay}) {
  final kind = skyKindFor(weatherCode);
  return (isDay ? _daySkies : _nightSkies)[kind]!;
}

/// A colour for a temperature, from icy blue through green and yellow to hot
/// red. Used for the bars in the 7-day forecast, so a warm week looks warm.
Color temperatureColor(double celsius) {
  const stops = <(double, Color)>[
    (-25.0, Color(0xFF5B6FD6)),
    (-10.0, Color(0xFF4F9BE0)),
    (0.0, Color(0xFF5CC0D0)),
    (10.0, Color(0xFF7CC68A)),
    (18.0, Color(0xFFE8C04A)),
    (26.0, Color(0xFFF08B3C)),
    (34.0, Color(0xFFD9452B)),
  ];
  if (celsius <= stops.first.$1) return stops.first.$2;
  for (var i = 1; i < stops.length; i++) {
    final (t1, c1) = stops[i];
    if (celsius <= t1) {
      final (t0, c0) = stops[i - 1];
      return Color.lerp(c0, c1, (celsius - t0) / (t1 - t0))!;
    }
  }
  return stops.last.$2;
}

/// Converts to Celsius when needed, so colours mean the same in °C and °F.
double toCelsius(double value, {required bool fahrenheit}) =>
    fahrenheit ? (value - 32) * 5 / 9 : value;

/// Numbers in the condensed face, with digits of equal width so they don't
/// jiggle when they change.
TextStyle numberStyle(double size, {FontWeight weight = FontWeight.w500, Color? color}) {
  return TextStyle(
    fontFamily: numberFont,
    fontSize: size,
    fontWeight: weight,
    height: 1.0,
    color: color,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
