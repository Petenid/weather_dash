import 'dart:math' as math;

/// Wind chill, using Environment and Climate Change Canada's formula.
/// Only meaningful when it's 10 °C or colder with at least 5 km/h of wind;
/// otherwise this returns null. Everything is in °C and km/h.
double? windChillC(double tempC, double windKmh) {
  if (tempC > 10 || windKmh < 5) return null;
  final v = math.pow(windKmh, 0.16);
  return 13.12 + 0.6215 * tempC - 11.37 * v + 0.3965 * tempC * v;
}

/// Humidex, the Canadian measure of how hot and humid it feels.
/// Environment Canada reports it when it's at least 20 °C and the humidex
/// reaches 25; otherwise this returns null.
double? humidexC(double tempC, int humidity) {
  if (tempC < 20) return null;
  // Water vapour pressure in hectopascals, from temperature and humidity.
  final vapour = humidity / 100 * 6.112 * math.exp(17.67 * tempC / (tempC + 243.5));
  final h = tempC + 0.5555 * (vapour - 10);
  return h < 25 ? null : h;
}

/// Converts a wind speed in [unit] ('kmh', 'ms', 'mph' or 'kn') to km/h.
double toKmh(double speed, String unit) => switch (unit) {
      'ms' => speed * 3.6,
      'mph' => speed * 1.609344,
      'kn' => speed * 1.852,
      _ => speed,
    };
