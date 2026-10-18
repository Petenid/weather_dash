import 'dart:convert';

import 'package:http/http.dart' as http;

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
    'language': 'en',
  });

  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('Search returned ${response.statusCode}');
  }

  final Map<String, dynamic> data;
  try {
    data = jsonDecode(response.body) as Map<String, dynamic>;
  } on FormatException {
    throw Exception('The search service had a temporary problem. Please try again.');
  }

  // When nothing matches, Open-Meteo leaves out "results" entirely.
  final results = data['results'] as List? ?? [];
  return [for (final r in results) Place.fromJson(r as Map<String, dynamic>)];
}