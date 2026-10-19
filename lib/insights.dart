import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aurora.dart';
import 'feels.dart';
import 'normals.dart';
import 'strings.dart';
import 'theme.dart';
import 'weather.dart';

/// Short, plain-language notes worked out from the forecast.
class InsightsSection extends StatelessWidget {
  const InsightsSection({
    super.key,
    required this.report,
    required this.fahrenheit,
    required this.normals,
    required this.aurora,
    required this.southern,
  });

  final WeatherReport report;
  final bool fahrenheit;
  final Normals? normals;
  final AuroraOutlook? aurora;
  final bool southern; // Southern hemisphere: "southern lights".

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notes = <(IconData, String)>[
      if (_comfortWarning() case final n?) (Icons.health_and_safety_outlined, n),
      if (_normalNote() case final n?) (Icons.history, n),
      if (_bestTimeNote() case final n?) (Icons.directions_walk, n),
      if (_frostNote() case final n?) (Icons.ac_unit, n),
      if (_auroraNote() case final n?) (Icons.auto_awesome, n),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t.atAGlance, style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        for (final (icon, text) in notes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(text, style: const TextStyle(fontSize: 16, height: 1.35)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  double _c(double value) => toCelsius(value, fahrenheit: fahrenheit);

  /// "Today's high of 6° is 4° colder than normal for October 18."
  String? _normalNote() {
    final n = normals;
    final today = report.today;
    if (n == null || today == null) return null;
    final diff = today.high - n.high;
    final date = t.dayMonth(today.date);
    final threshold = fahrenheit ? 3.0 : 1.5;
    if (diff.abs() < threshold) return t.normalAbout(degrees(today.high), date);
    return t.normalDiff(degrees(today.high), diff.abs().round(), diff > 0, date, degrees(n.high));
  }

  /// Finds the most pleasant two daylight hours in the next day: dry, not
  /// too windy, and as close to a comfortable 20 °C as possible.
  String? _bestTimeNote() {
    final hours = report.next24Hours;
    double score(HourlyPoint h) =>
        h.precipitationChance * 1.0 + (_c(h.temperature) - 20).abs() * 2 + h.windGusts * 0.15;

    int? best;
    var bestScore = double.infinity;
    for (var i = 0; i + 1 < hours.length; i++) {
      if (!hours[i].isDay || !hours[i + 1].isDay) continue;
      final s = score(hours[i]) + score(hours[i + 1]);
      if (s < bestScore) {
        bestScore = s;
        best = i;
      }
    }
    if (best == null) return null;

    final start = hours[best].time;
    final end = start.add(const Duration(hours: 2));
    final now = report.current.time;
    final temp = degrees((hours[best].temperature + hours[best + 1].temperature) / 2);
    final rain = math.max(hours[best].precipitationChance, hours[best + 1].precipitationChance);
    return t.bestTime(start.day == now.day, hoursMinutes(start), hoursMinutes(end), temp, rain);
  }

  /// Warns about frost tonight, or says when the next frost is due.
  String? _frostNote() {
    final now = report.current.time;
    final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 9);
    final tonight = [
      for (final h in report.allHours)
        if (!h.time.isBefore(now) && h.time.isBefore(tomorrowMorning)) h.temperature,
    ];
    if (tonight.isNotEmpty) {
      final low = tonight.reduce(math.min);
      if (_c(low) <= 0) {
        return t.frostTonight(degrees(low));
      }
    }
    for (var i = 2; i < report.daily.length; i++) {
      final day = report.daily[i];
      if (_c(day.low) <= 0) {
        return t.nextFrost(day.date, degrees(day.low));
      }
    }
    return null;
  }

  String? _auroraNote() {
    final a = aurora;
    if (a == null) return null;
    return t.auroraNote(
      southern,
      t.auroraChance(a.chance),
      t.decimal(a.maxKp, 1),
      a.kpNeeded.toStringAsFixed(0),
      _cloudyTonight(),
    );
  }

  /// A warning when the wind chill or humidex reaches a level where
  /// Environment Canada advises taking care.
  String? _comfortWarning() {
    final now = report.current;
    final tempC = _c(now.temperature);
    double shown(double c) => fahrenheit ? c * 9 / 5 + 32 : c;
    final chill = windChillC(tempC, toKmh(now.windSpeed, report.windUnit));
    if (chill != null && chill <= -28) {
      return t.windChillWarning(degrees(shown(chill)), t.windChillRisk(chill));
    }
    final humidex = humidexC(tempC, now.humidity);
    if (humidex != null && humidex >= 40) {
      // Humidex is always given on the Celsius scale, even in °F.
      return t.humidexWarning('${humidex.round()}', t.humidexLevel(humidex));
    }
    return null;
  }

  /// True if most hours between 22:00 and 02:00 tonight are overcast or wet.
  bool _cloudyTonight() {
    final now = report.current.time;
    final start = DateTime(now.year, now.month, now.day, 22);
    final end = start.add(const Duration(hours: 4));
    final night = [
      for (final h in report.allHours)
        if (!h.time.isBefore(start) && h.time.isBefore(end)) h.weatherCode,
    ];
    if (night.isEmpty) return false;
    return night.where((c) => c >= 3).length > night.length / 2;
  }
}
