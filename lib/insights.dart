import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'aurora.dart';
import 'normals.dart';
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
      if (_normalNote() case final n?) (Icons.history, n),
      if (_bestTimeNote() case final n?) (Icons.directions_walk, n),
      if (_frostNote() case final n?) (Icons.ac_unit, n),
      if (_auroraNote() case final n?) (Icons.auto_awesome, n),
    ];
    if (notes.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('At a glance', style: theme.textTheme.titleMedium),
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
    final date = '${_months[today.date.month - 1]} ${today.date.day}';
    final threshold = fahrenheit ? 3.0 : 1.5;
    if (diff.abs() < threshold) {
      return "Today's high of ${degrees(today.high)} is about normal for $date.";
    }
    final way = diff > 0 ? 'warmer' : 'colder';
    return "Today's high of ${degrees(today.high)} is ${diff.abs().round()}° $way than "
        'normal for $date. The 30-year average high is ${degrees(n.high)}.';
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
    final when = start.day == now.day ? 'today' : 'tomorrow';
    final temp = degrees((hours[best].temperature + hours[best + 1].temperature) / 2);
    final rain = math.max(hours[best].precipitationChance, hours[best + 1].precipitationChance);
    final sky = rain < 20 ? 'and likely dry' : 'with a $rain% chance of rain or snow';
    return 'Best time to be outside $when: ${hoursMinutes(start)} to ${hoursMinutes(end)}, '
        'around $temp $sky.';
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
        return 'Frost likely tonight, down to ${degrees(low)}. '
            'Cover tender plants and expect icy windshields in the morning.';
      }
    }
    for (var i = 2; i < report.daily.length; i++) {
      final day = report.daily[i];
      if (_c(day.low) <= 0) {
        return 'No frost tonight. The next frost looks likely early '
            '${_weekdays[day.date.weekday - 1]} morning, down to ${degrees(day.low)}.';
      }
    }
    return null;
  }

  String? _auroraNote() {
    final a = aurora;
    if (a == null) return null;
    final lights = southern ? 'Southern lights' : 'Northern lights';
    final note = '$lights tonight: ${a.chance.toLowerCase()}. Geomagnetic activity '
        'should reach about Kp ${a.maxKp.toStringAsFixed(1)}; seeing them from here '
        'usually takes Kp ${a.kpNeeded.toStringAsFixed(0)} or more.';
    return '${note[0].toUpperCase()}${note.substring(1)}${_cloudyTonight() ? ' Cloud may hide the sky.' : ''}';
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

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];
