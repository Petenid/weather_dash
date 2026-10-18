import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// The current conditions we care about, pulled out of Open-Meteo's JSON.
class CurrentWeather {
  final double temperature;
  final double feelsLike;
  final int humidity;
  final double windSpeed;
  final int windDirection;
  final int weatherCode;
  final bool isDay;
  final DateTime time;

  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.isDay,
    required this.time,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      temperature: (json['temperature_2m'] as num).toDouble(),
      feelsLike: (json['apparent_temperature'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      windSpeed: (json['wind_speed_10m'] as num).toDouble(),
      windDirection: (json['wind_direction_10m'] as num).toInt(),
      weatherCode: (json['weather_code'] as num).toInt(),
      isDay: json['is_day'] == 1,
      time: DateTime.parse(json['time'] as String),
    );
  }
}

/// Asks Open-Meteo for the current conditions at a location.
Future<CurrentWeather> fetchCurrentWeather(double lat, double lon) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
    'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
        'is_day,weather_code,wind_speed_10m,wind_direction_10m',
    'timezone': 'auto',
  });

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw Exception('Open-Meteo returned ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return CurrentWeather.fromJson(data['current'] as Map<String, dynamic>);
}

/// WMO weather codes, from the Open-Meteo docs.
const Map<int, String> _descriptions = {
  0: 'Clear sky',
  1: 'Mainly clear',
  2: 'Partly cloudy',
  3: 'Overcast',
  45: 'Fog',
  48: 'Depositing rime fog',
  51: 'Light drizzle',
  53: 'Moderate drizzle',
  55: 'Dense drizzle',
  56: 'Light freezing drizzle',
  57: 'Dense freezing drizzle',
  61: 'Slight rain',
  63: 'Moderate rain',
  65: 'Heavy rain',
  66: 'Light freezing rain',
  67: 'Heavy freezing rain',
  71: 'Slight snowfall',
  73: 'Moderate snowfall',
  75: 'Heavy snowfall',
  77: 'Snow grains',
  80: 'Slight rain showers',
  81: 'Moderate rain showers',
  82: 'Violent rain showers',
  85: 'Slight snow showers',
  86: 'Heavy snow showers',
  95: 'Thunderstorm',
  96: 'Thunderstorm with slight hail',
  97: 'Heavy thunderstorm',
  99: 'Thunderstorm with heavy hail',
};

String describeWeather(int code) => _descriptions[code] ?? 'Unknown';

IconData weatherIcon(int code, {required bool isDay}) {
  return switch (code) {
    0 || 1 => isDay ? Icons.wb_sunny : Icons.nights_stay,
    2 => isDay ? Icons.wb_cloudy : Icons.nights_stay,
    3 => Icons.cloud,
    45 || 48 => Icons.blur_on,
    >= 51 && <= 57 => Icons.grain,
    (>= 61 && <= 67) || (>= 80 && <= 82) => Icons.water_drop,
    (>= 71 && <= 77) || 85 || 86 => Icons.ac_unit,
    >= 95 => Icons.flash_on,
    _ => Icons.help_outline,
  };
}

/// Turns 0–360° into N, NE, E, and so on.
String compassDirection(int degrees) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return directions[((degrees % 360) / 45).round() % 8];
}