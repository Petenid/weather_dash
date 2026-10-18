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

/// One hour of the hourly forecast.
class HourlyPoint {
  final DateTime time;
  final double temperature;

  const HourlyPoint({required this.time, required this.temperature});
}

/// One day of the daily forecast.
class DailyForecast {
  final DateTime date;
  final int weatherCode;
  final double high;
  final double low;
  final int precipitationChance;

  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.high,
    required this.low,
    required this.precipitationChance,
  });
}

/// Everything one request gives us.
class WeatherReport {
  final CurrentWeather current;
  final List<HourlyPoint> hourly;
  final List<DailyForecast> daily;

  const WeatherReport({
    required this.current,
    required this.hourly,
    required this.daily,
  });
}

/// Asks Open-Meteo for current conditions, the next 24 hours,
/// and a 7-day forecast.
Future<WeatherReport> fetchWeather(double lat, double lon) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
    'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
        'is_day,weather_code,wind_speed_10m,wind_direction_10m',
    'hourly': 'temperature_2m',
    'forecast_hours': '24',
    'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max',
    'forecast_days': '7',
    'timezone': 'auto',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('Open-Meteo returned ${response.statusCode}');
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } on FormatException {
    throw Exception('Open-Meteo had a temporary problem. Please try again.');
  }

  // Hourly data comes as two lined-up lists: times and temperatures.
  final hourly = data['hourly'] as Map<String, dynamic>;
  final hourTimes = hourly['time'] as List;
  final hourTemps = hourly['temperature_2m'] as List;

  final hours = [
    for (var i = 0; i < hourTimes.length; i++)
      HourlyPoint(
        time: DateTime.parse(hourTimes[i] as String),
        temperature: (hourTemps[i] as num).toDouble(),
      ),
  ];

  // Daily data works the same way, with more lists.
  final daily = data['daily'] as Map<String, dynamic>;
  final dates = daily['time'] as List;
  final codes = daily['weather_code'] as List;
  final highs = daily['temperature_2m_max'] as List;
  final lows = daily['temperature_2m_min'] as List;
  final rainChances = daily['precipitation_probability_max'] as List;

  final days = [
    for (var i = 0; i < dates.length; i++)
      DailyForecast(
        date: DateTime.parse(dates[i] as String),
        weatherCode: (codes[i] as num).toInt(),
        high: (highs[i] as num).toDouble(),
        low: (lows[i] as num).toDouble(),
        precipitationChance: (rainChances[i] as num?)?.toInt() ?? 0,
      ),
  ];

  return WeatherReport(
    current: CurrentWeather.fromJson(data['current'] as Map<String, dynamic>),
    hourly: hours,
    daily: days,
  );
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