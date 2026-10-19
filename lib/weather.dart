import 'dart:async';
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
  final double? uvIndex;
  final DateTime time;

  const CurrentWeather({
    required this.temperature,
    required this.feelsLike,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
    required this.isDay,
    required this.uvIndex,
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
      uvIndex: (json['uv_index'] as num?)?.toDouble(),
      time: DateTime.parse(json['time'] as String),
    );
  }
}

/// One hour of the hourly forecast.
class HourlyPoint {
  final DateTime time;
  final double temperature;
  final int precipitationChance; // %
  final double precipitation; // mm (or inches)
  final double windSpeed;
  final double windGusts;
  final int weatherCode;
  final bool isDay;

  const HourlyPoint({
    required this.time,
    required this.temperature,
    required this.precipitationChance,
    required this.precipitation,
    required this.windSpeed,
    required this.windGusts,
    required this.weatherCode,
    required this.isDay,
  });
}

/// One day of the daily forecast.
class DailyForecast {
  final DateTime date;
  final int weatherCode;
  final double high;
  final double low;
  final int precipitationChance;
  final double precipitationTotal;
  final double windMax;
  final double gustMax;
  final int? windDirection;
  final DateTime? sunrise;
  final DateTime? sunset;
  final double? uvMax;

  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.high,
    required this.low,
    required this.precipitationChance,
    required this.precipitationTotal,
    required this.windMax,
    required this.gustMax,
    required this.windDirection,
    required this.sunrise,
    required this.sunset,
    required this.uvMax,
  });
}

/// Everything one request gives us.
class WeatherReport {
  final CurrentWeather current;

  /// Every hour of the 7 days, starting at midnight today.
  final List<HourlyPoint> allHours;
  final List<DailyForecast> daily;
  final String tempUnit;
  final String windUnit;
  final String precipUnit;

  const WeatherReport({
    required this.current,
    required this.allHours,
    required this.daily,
    required this.tempUnit,
    required this.windUnit,
    required this.precipUnit,
  });

  /// Today's forecast (the first day), or null if the list is empty.
  DailyForecast? get today => daily.isEmpty ? null : daily.first;

  /// The 24 hours starting with the current hour.
  List<HourlyPoint> get next24Hours {
    final now = current.time;
    final thisHour = DateTime(now.year, now.month, now.day, now.hour);
    final start = allHours.indexWhere((h) => !h.time.isBefore(thisHour));
    if (start < 0) return const [];
    final end = start + 24 > allHours.length ? allHours.length : start + 24;
    return allHours.sublist(start, end);
  }

  /// The 24 hours of one calendar day.
  List<HourlyPoint> hoursOn(DateTime day) => [
        for (final h in allHours)
          if (h.time.year == day.year && h.time.month == day.month && h.time.day == day.day) h,
      ];
}

/// Asks Open-Meteo for current conditions and 7 days of hourly and daily
/// forecasts.
/// Wind speed units Open-Meteo understands, and how we label them.
const windUnits = {'kmh': 'km/h', 'ms': 'm/s', 'mph': 'mph', 'kn': 'knots'};

/// Downloads the forecast as JSON text. Kept separate from reading it, so
/// the text can be saved and shown again when there's no internet.
Future<String> fetchForecastJson(
  double lat,
  double lon, {
  bool fahrenheit = false,
  String windUnit = 'kmh',
}) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
    'current': 'temperature_2m,apparent_temperature,relative_humidity_2m,'
        'is_day,weather_code,wind_speed_10m,wind_direction_10m,uv_index',
    'hourly': 'temperature_2m,precipitation_probability,precipitation,'
        'wind_speed_10m,wind_gusts_10m,weather_code,is_day',
    'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
        'precipitation_probability_max,precipitation_sum,wind_speed_10m_max,'
        'wind_gusts_10m_max,wind_direction_10m_dominant,sunrise,sunset,uv_index_max',
    'forecast_days': '7',
    'timezone': 'auto',
    'wind_speed_unit': windUnit,
    if (fahrenheit) 'temperature_unit': 'fahrenheit',
    if (fahrenheit) 'precipitation_unit': 'inch',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('Open-Meteo returned error ${response.statusCode}.');
  }
  return response.body;
}

/// Turns the forecast JSON text into a [WeatherReport].
WeatherReport parseForecast(
  String json, {
  required bool fahrenheit,
  required String windUnit,
}) {
  final Map<String, dynamic> data;
  try {
    data = jsonDecode(json) as Map<String, dynamic>;
  } on FormatException {
    throw Exception('Open-Meteo had a temporary problem.');
  }

  // Open-Meteo sends each variable as its own list; item i of every list
  // belongs to the same hour (or day). These helpers read item i safely.
  final hourly = data['hourly'] as Map<String, dynamic>;
  double num0(Map<String, dynamic> m, String key, int i) =>
      ((m[key] as List?)?[i] as num?)?.toDouble() ?? 0;

  final hourTimes = hourly['time'] as List;
  final hours = [
    for (var i = 0; i < hourTimes.length; i++)
      if ((hourly['temperature_2m'] as List)[i] != null)
        HourlyPoint(
          time: DateTime.parse(hourTimes[i] as String),
          temperature: num0(hourly, 'temperature_2m', i),
          precipitationChance: num0(hourly, 'precipitation_probability', i).round(),
          precipitation: num0(hourly, 'precipitation', i),
          windSpeed: num0(hourly, 'wind_speed_10m', i),
          windGusts: num0(hourly, 'wind_gusts_10m', i),
          weatherCode: num0(hourly, 'weather_code', i).round(),
          isDay: num0(hourly, 'is_day', i) == 1,
        ),
  ];

  final daily = data['daily'] as Map<String, dynamic>;
  final dates = daily['time'] as List;
  final days = [
    for (var i = 0; i < dates.length; i++)
      DailyForecast(
        date: DateTime.parse(dates[i] as String),
        weatherCode: (((daily['weather_code'] as List)[i]) as num?)?.toInt() ?? -1,
        high: num0(daily, 'temperature_2m_max', i),
        low: num0(daily, 'temperature_2m_min', i),
        precipitationChance: num0(daily, 'precipitation_probability_max', i).round(),
        precipitationTotal: num0(daily, 'precipitation_sum', i),
        windMax: num0(daily, 'wind_speed_10m_max', i),
        gustMax: num0(daily, 'wind_gusts_10m_max', i),
        windDirection:
            (((daily['wind_direction_10m_dominant'] as List?)?[i]) as num?)?.toInt(),
        sunrise: _parseTime((daily['sunrise'] as List)[i]),
        sunset: _parseTime((daily['sunset'] as List)[i]),
        uvMax: (((daily['uv_index_max'] as List?)?[i]) as num?)?.toDouble(),
      ),
  ];

  return WeatherReport(
    current: CurrentWeather.fromJson(data['current'] as Map<String, dynamic>),
    allHours: hours,
    daily: days,
    tempUnit: fahrenheit ? '°F' : '°C',
    windUnit: windUnits[windUnit] ?? windUnit,
    precipUnit: fahrenheit ? 'in' : 'mm',
  );
}

/// Reads a time like "2026-10-18T07:22", or returns null if it's missing.
DateTime? _parseTime(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Turns an error into a sentence a person can act on.
String friendlyError(Object error) {
  if (error is TimeoutException) {
    return 'Open-Meteo took too long to answer. Check your connection and try again.';
  }
  if (error is http.ClientException) {
    return "Can't reach Open-Meteo. Check your internet connection and try again.";
  }
  return error.toString().replaceFirst('Exception: ', '');
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
    0 || 1 => isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
    2 => isDay ? Icons.wb_cloudy_outlined : Icons.nights_stay_outlined,
    3 => Icons.cloud_outlined,
    45 || 48 => Icons.blur_on,
    >= 51 && <= 57 => Icons.grain,
    (>= 61 && <= 67) || (>= 80 && <= 82) => Icons.water_drop_outlined,
    (>= 71 && <= 77) || 85 || 86 => Icons.ac_unit,
    >= 95 => Icons.bolt,
    _ => Icons.help_outline,
  };
}

/// Turns 0–360° into N, NE, E, and so on.
String compassDirection(int degrees) {
  const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
  return directions[((degrees % 360) / 45).round() % 8];
}

/// The standard WHO wording for a UV index value.
String uvLevel(double uv) {
  if (uv < 3) return 'Low';
  if (uv < 6) return 'Moderate';
  if (uv < 8) return 'High';
  if (uv < 11) return 'Very high';
  return 'Extreme';
}

/// A rounded temperature like "−3°", using a proper minus sign.
String degrees(double value) => '${value.round()}°'.replaceFirst('-', '−');

/// Whether times show as "13:05" (true) or "1:05 pm" (false). Set from the
/// settings screen.
bool use24HourClock = true;

/// A time of day, in the clock style chosen in settings.
String hoursMinutes(DateTime t) {
  final mm = t.minute.toString().padLeft(2, '0');
  if (use24HourClock) return '${t.hour.toString().padLeft(2, '0')}:$mm';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final suffix = t.hour < 12 ? 'am' : 'pm';
  return mm == '00' ? '$h $suffix' : '$h:$mm $suffix';
}
