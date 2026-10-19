import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'strings.dart';

/// Current air quality, from Open-Meteo's air quality service (CAMS data).
class AirQuality {
  final int? usAqi; // US Air Quality Index, 0 to 500
  final double? pm25; // fine particles, µg/m³
  final double? ozone; // µg/m³

  const AirQuality({required this.usAqi, required this.pm25, required this.ozone});
}

Future<AirQuality> fetchAirQuality(double lat, double lon) async {
  final uri = Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
    'latitude': '$lat',
    'longitude': '$lon',
    'current': 'us_aqi,pm2_5,ozone',
    'timezone': 'auto',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError(t.airService, response.statusCode));
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } on FormatException {
    throw Exception(t.serviceHiccup(t.airService));
  }

  final current = data['current'] as Map<String, dynamic>? ?? const {};
  return AirQuality(
    usAqi: (current['us_aqi'] as num?)?.round(),
    pm25: (current['pm2_5'] as num?)?.toDouble(),
    ozone: (current['ozone'] as num?)?.toDouble(),
  );
}

/// The official US AQI category names.
String aqiLevel(int aqi) => t.aqiLevel(aqi);

/// The standard colours that go with each AQI category. Always shown next to
/// the category name, never on their own.
Color aqiColor(int aqi) {
  if (aqi <= 50) return const Color(0xFF3BB54A);
  if (aqi <= 100) return const Color(0xFFE8C21C);
  if (aqi <= 150) return const Color(0xFFF08A24);
  if (aqi <= 200) return const Color(0xFFE5322D);
  if (aqi <= 300) return const Color(0xFF8F3F97);
  return const Color(0xFF7E0023);
}
