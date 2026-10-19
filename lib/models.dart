import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'strings.dart';

/// One national weather service's forecast model.
class ForecastModel {
  final String id; // Open-Meteo's name for it

  const ForecastModel(this.id);

  /// What we show, in the current language.
  String get name => switch (id) {
        'gem_seamless' => t.canada,
        'gfs_seamless' => t.unitedStates,
        _ => t.europe,
      };

  /// Who runs it.
  String get source => switch (id) {
        'gem_seamless' => t.gemSource,
        'gfs_seamless' => t.gfsSource,
        _ => t.ecmwfSource,
      };
}

/// The three models we compare. Open-Meteo's main forecast blends several
/// models together; this shows what three of them say on their own.
const comparedModels = [
  ForecastModel('gem_seamless'),
  ForecastModel('gfs_seamless'),
  ForecastModel('ecmwf_ifs025'),
];

/// What one model predicts. Values can be null where a model has no data.
class ModelRun {
  final ForecastModel model;
  final List<double?> hourly;
  final List<double?> highs;
  final List<double?> lows;

  const ModelRun({
    required this.model,
    required this.hourly,
    required this.highs,
    required this.lows,
  });
}

/// Every model's forecast for the same hours and days.
class ModelComparison {
  final List<DateTime> hours;
  final List<DateTime> days;
  final List<ModelRun> runs;
  final String tempUnit;

  const ModelComparison({
    required this.hours,
    required this.days,
    required this.runs,
    required this.tempUnit,
  });

  /// How far apart the models' highs are on each day (null if fewer than
  /// two models have a value that day).
  List<double?> get highSpreads => [
        for (var d = 0; d < days.length; d++) _spread([for (final r in runs) r.highs[d]]),
      ];
}

double? _spread(List<double?> values) {
  final known = values.whereType<double>().toList();
  if (known.length < 2) return null;
  return known.reduce(math.max) - known.reduce(math.min);
}

/// Asks Open-Meteo for the next 3 days hour by hour, and 7 days of highs and
/// lows, from each model in [comparedModels].
Future<ModelComparison> fetchModelComparison(
  double lat,
  double lon, {
  bool fahrenheit = false,
}) async {
  final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': '$lat',
    'longitude': '$lon',
    'hourly': 'temperature_2m',
    'forecast_hours': '72',
    'daily': 'temperature_2m_max,temperature_2m_min',
    'forecast_days': '7',
    'timezone': 'auto',
    'models': comparedModels.map((m) => m.id).join(','),
    if (fahrenheit) 'temperature_unit': 'fahrenheit',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 20));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError('Open-Meteo', response.statusCode));
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } on FormatException {
    throw Exception(t.serviceHiccup('Open-Meteo'));
  }

  final hourly = data['hourly'] as Map<String, dynamic>;
  final daily = data['daily'] as Map<String, dynamic>;

  // When you ask for several models, Open-Meteo adds the model's name to
  // each key: "temperature_2m_gem_seamless", "temperature_2m_gfs_seamless"...
  List<double?> numbers(Map<String, dynamic> section, String key, String modelId) {
    final list = section['${key}_$modelId'] as List? ?? const [];
    return [for (final v in list) (v as num?)?.toDouble()];
  }

  final hours = [for (final t in hourly['time'] as List) DateTime.parse(t as String)];
  final days = [for (final t in daily['time'] as List) DateTime.parse(t as String)];

  final runs = <ModelRun>[];
  for (final model in comparedModels) {
    final temps = numbers(hourly, 'temperature_2m', model.id);
    // Skip a model that sent nothing for this place.
    if (temps.whereType<double>().isEmpty) continue;
    runs.add(ModelRun(
      model: model,
      hourly: _fit(temps, hours.length),
      highs: _fit(numbers(daily, 'temperature_2m_max', model.id), days.length),
      lows: _fit(numbers(daily, 'temperature_2m_min', model.id), days.length),
    ));
  }

  if (runs.isEmpty) {
    throw Exception(t.noModels);
  }

  return ModelComparison(
    hours: hours,
    days: days,
    runs: runs,
    tempUnit: fahrenheit ? '°F' : '°C',
  );
}

/// Pads or trims a list to exactly [length] items, so every model lines up.
List<double?> _fit(List<double?> values, int length) => [
      for (var i = 0; i < length; i++) i < values.length ? values[i] : null,
    ];
