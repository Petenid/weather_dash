import 'dart:convert';

import 'package:http/http.dart' as http;
import 'strings.dart';

/// What's normal for this place and date: the average high and low over 30
/// years, from Open-Meteo's historical weather records.
class Normals {
  final double high;
  final double low;

  const Normals({required this.high, required this.low});
}

// Thirty years of daily records is a large download, so each place's answer
// is kept for the rest of the session.
final _cache = <String, Normals>{};

Future<Normals> fetchNormals(
  double lat,
  double lon,
  DateTime day, {
  bool fahrenheit = false,
}) async {
  final key = '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)},${day.month}-${day.day},$fahrenheit';
  final cached = _cache[key];
  if (cached != null) return cached;

  final uri = Uri.https('archive-api.open-meteo.com', '/v1/archive', {
    'latitude': '$lat',
    'longitude': '$lon',
    'start_date': '1996-01-01',
    'end_date': '2025-12-31',
    'daily': 'temperature_2m_max,temperature_2m_min',
    'timezone': 'auto',
    if (fahrenheit) 'temperature_unit': 'fahrenheit',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 30));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError(t.historyService, response.statusCode));
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final daily = data['daily'] as Map<String, dynamic>;
  final dates = daily['time'] as List;
  final highs = daily['temperature_2m_max'] as List;
  final lows = daily['temperature_2m_min'] as List;

  // Average every year's values for the same date, give or take 3 days,
  // which smooths out the odd unusual day.
  var highSum = 0.0, lowSum = 0.0;
  var count = 0;
  for (var i = 0; i < dates.length; i++) {
    final d = DateTime.parse(dates[i] as String);
    final sameDay = DateTime(day.year, d.month, d.day);
    final gap = sameDay.difference(DateTime(day.year, day.month, day.day)).inDays.abs();
    // Dates near New Year wrap around (Dec 30 is close to Jan 2).
    if (gap > 3 && gap < 362) continue;
    final h = highs[i], l = lows[i];
    if (h is! num || l is! num) continue;
    highSum += h;
    lowSum += l;
    count++;
  }
  if (count == 0) throw Exception(t.noHistory);

  final normals = Normals(high: highSum / count, low: lowSum / count);
  _cache[key] = normals;
  return normals;
}
