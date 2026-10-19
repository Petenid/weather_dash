import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'places.dart';

/// The last forecast that downloaded successfully, saved so the app has
/// something to show when there's no internet.
class CachedForecast {
  final Place place;
  final bool fahrenheit;
  final String windUnit;
  final String json;

  const CachedForecast({
    required this.place,
    required this.fahrenheit,
    required this.windUnit,
    required this.json,
  });
}

const _key = 'lastForecast';

Future<void> saveForecast(CachedForecast f) async {
  try {
    await SharedPreferencesAsync().setString(
      _key,
      jsonEncode({
        'place': f.place.toJson(),
        'fahrenheit': f.fahrenheit,
        'windUnit': f.windUnit,
        'json': f.json,
      }),
    );
  } catch (_) {
    // Not being able to save the offline copy isn't worth interrupting for.
  }
}

Future<CachedForecast?> loadForecast() async {
  try {
    final text = await SharedPreferencesAsync().getString(_key);
    if (text == null) return null;
    final m = jsonDecode(text) as Map<String, dynamic>;
    return CachedForecast(
      place: Place.fromJson(m['place'] as Map<String, dynamic>),
      fahrenheit: m['fahrenheit'] as bool? ?? false,
      windUnit: m['windUnit'] as String? ?? 'kmh',
      json: m['json'] as String,
    );
  } catch (_) {
    return null;
  }
}
