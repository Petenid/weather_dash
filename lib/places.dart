import 'dart:convert';

import 'package:http/http.dart' as http;
import 'strings.dart';

/// A place you can get weather for.
class Place {
  final String name;
  final String? region;
  final String? country;
  final double latitude;
  final double longitude;

  const Place({
    required this.name,
    this.region,
    this.country,
    required this.latitude,
    required this.longitude,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['name'] as String,
      region: json['admin1'] as String?,
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

    /// Turns a place back into JSON so we can save it.
  /// Uses the same keys as fromJson, so a saved place loads with fromJson.
  Map<String, dynamic> toJson() => {
        'name': name,
        'admin1': region,
        'country': country,
        'latitude': latitude,
        'longitude': longitude,
      };

  /// True if this is the same spot as [other] (within about a kilometre).
  bool sameAs(Place other) =>
      (latitude - other.latitude).abs() < 0.01 &&
      (longitude - other.longitude).abs() < 0.01;

  /// Short name for the dashboard, e.g. "North Bay, Ontario".
  String get label {
    final r = region;
    return (r == null || r.isEmpty) ? name : '$name, $r';
  }

  /// Extra detail for search results, e.g. "Ontario, Canada".
  String get details =>
      [region, country].where((s) => s != null && s.isNotEmpty).join(', ');
}

/// Looks up places by name using Open-Meteo's geocoding service.
Future<List<Place>> searchPlaces(String query) async {
  final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
    'name': query,
    'count': '10',
    'language': t.fr ? 'fr' : 'en', // French gives "Montréal", "Québec"...
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError(t.searchService, response.statusCode));
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } on FormatException {
    throw Exception(t.serviceHiccup(t.searchService));
  }

  // When nothing matches, Open-Meteo leaves out "results" entirely.
  final results = data['results'] as List? ?? [];
  return [for (final r in results) Place.fromJson(r as Map<String, dynamic>)];
}