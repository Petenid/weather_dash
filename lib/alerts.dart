import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'strings.dart';

/// An official weather alert from Environment and Climate Change Canada.
class WeatherAlert {
  final String name; // e.g. "Snowfall warning"
  final String area;
  final String text;
  final String colour; // "red", "orange", "yellow" or ""
  final DateTime? expires;

  const WeatherAlert({
    required this.name,
    required this.area,
    required this.text,
    required this.colour,
    required this.expires,
  });

  Color get displayColor => switch (colour) {
        'red' => const Color(0xFFE5322D),
        'orange' => const Color(0xFFF08A24),
        'yellow' => const Color(0xFFE8C21C),
        _ => const Color(0xFF9AA8B3),
      };
}

/// Active alerts covering this spot. Outside Canada this is simply empty.
Future<List<WeatherAlert>> fetchAlerts(double lat, double lon) async {
  // A tiny box around the place; the service returns alerts whose areas
  // overlap it.
  const d = 0.02;
  final uri = Uri.https('api.weather.gc.ca', '/collections/weather-alerts/items', {
    'f': 'json',
    'lang': t.fr ? 'fr' : 'en',
    'bbox': '${lon - d},${lat - d},${lon + d},${lat + d}',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError('Environment Canada', response.statusCode));
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final features = data['features'] as List? ?? const [];
  final now = DateTime.now().toUtc();

  final alerts = <String, WeatherAlert>{};
  for (final f in features) {
    final p = (f as Map<String, dynamic>)['properties'] as Map<String, dynamic>? ?? const {};
    // The service sends each text in both languages: alert_name_en, alert_name_fr...
    final lang = t.fr ? 'fr' : 'en';
    final name = (p['alert_name_$lang'] ?? p['alert_short_name_$lang'] ?? p['alert_name_en'] ?? '')
        .toString()
        .trim();
    if (name.isEmpty) continue;

    final expires = DateTime.tryParse('${p['expiration_datetime'] ?? ''}');
    if (expires != null && expires.toUtc().isBefore(now)) continue; // Already over.

    // The same alert comes once per area it covers; keep one of each.
    alerts.putIfAbsent(
      name.toLowerCase(),
      () => WeatherAlert(
        name: name[0].toUpperCase() + name.substring(1),
        area: (p['feature_name_$lang'] ?? p['feature_name_en'] ?? '').toString(),
        text: (p['alert_text_$lang'] ?? p['alert_text_en'] ?? '').toString().trim(),
        colour: (p['risk_colour_en'] ?? '').toString().toLowerCase(),
        expires: expires?.toLocal(),
      ),
    );
  }
  return alerts.values.toList();
}
