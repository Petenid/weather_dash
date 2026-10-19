import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import 'places.dart';
import 'strings.dart';

/// Finds where this computer is, using Windows location services, and names
/// the place using OpenStreetMap's Nominatim service.
Future<Place> locateMe() async {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw Exception(t.locationOff);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw Exception(t.locationDenied);
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.low, // A town-level fix is plenty for weather.
      timeLimit: Duration(seconds: 20),
    ),
  );
  final lat = position.latitude;
  final lon = position.longitude;

  // Turn the coordinates into a town name. If that fails, still use the spot.
  try {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': '$lat',
      'lon': '$lon',
      'format': 'jsonv2',
      'zoom': '10',
      'accept-language': t.fr ? 'fr' : 'en',
    });
    // Nominatim asks every app to say who it is. Browsers don't let web
    // pages set this themselves (they send their own), so only the desktop
    // app adds it.
    final response = await http
        .get(uri, headers: {
          if (!kIsWeb) 'User-Agent': 'WeatherDash/1.0 (github.com/Petenid/weather_dash)',
        })
        .timeout(const Duration(seconds: 10));
    final address = (jsonDecode(response.body) as Map<String, dynamic>)['address']
        as Map<String, dynamic>?;
    final name = address?['city'] ?? address?['town'] ?? address?['village'] ??
        address?['municipality'] ?? address?['county'];
    if (name != null) {
      return Place(
        name: name.toString(),
        region: address?['state']?.toString(),
        country: address?['country']?.toString(),
        latitude: lat,
        longitude: lon,
      );
    }
  } catch (_) {
    // Fall through to an unnamed place.
  }
  return Place(name: t.myLocation, latitude: lat, longitude: lon);
}
