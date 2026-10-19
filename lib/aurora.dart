import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'strings.dart';

/// The chance of seeing the northern (or southern) lights tonight.
class AuroraOutlook {
  final double maxKp; // Strongest geomagnetic activity expected in the next 24 h, 0–9.
  final double kpNeeded; // Roughly how strong it must be to see it from here.

  const AuroraOutlook({required this.maxKp, required this.kpNeeded});

  /// 'good', 'possible' or 'unlikely'. Shown in words with `t.auroraChance`.
  String get chance {
    if (maxKp >= kpNeeded) return 'good';
    if (maxKp >= kpNeeded - 1) return 'possible';
    return 'unlikely';
  }
}

/// How far a place is from the magnetic pole, in "magnetic latitude".
/// Auroras follow the magnetic pole (in northern Canada), not the
/// geographic one, which is why they're more common in Quebec than at the
/// same latitude in Europe. Uses a simple tilted-dipole model of Earth's
/// magnetic field, which is close enough for this.
double magneticLatitude(double lat, double lon) {
  const poleLat = 80.7 * math.pi / 180;
  const poleLon = -72.7 * math.pi / 180;
  final phi = lat * math.pi / 180;
  final lambda = lon * math.pi / 180;
  final s = math.sin(phi) * math.sin(poleLat) +
      math.cos(phi) * math.cos(poleLat) * math.cos(lambda - poleLon);
  return math.asin(s.clamp(-1.0, 1.0)) * 180 / math.pi;
}

/// True if auroras are ever realistically visible from here.
bool auroraRelevant(double lat, double lon) => magneticLatitude(lat, lon).abs() >= 45;

/// Asks NOAA's Space Weather Prediction Center for the Kp forecast.
Future<AuroraOutlook> fetchAuroraOutlook(double lat, double lon) async {
  final uri = Uri.https(
    'services.swpc.noaa.gov',
    '/products/noaa-planetary-k-index-forecast.json',
  );
  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception(t.serviceError('NOAA', response.statusCode));
  }

  final rows = jsonDecode(response.body) as List;
  final now = DateTime.now().toUtc();
  final soon = now.add(const Duration(hours: 24));
  var maxKp = 0.0;

  // NOAA has sent this as a table (a header row, then lists) and as a list
  // of objects, so read either.
  for (final row in rows) {
    String? time;
    Object? kp;
    if (row is List && row.length >= 2) {
      time = row[0]?.toString();
      kp = row[1];
    } else if (row is Map) {
      time = row['time_tag']?.toString();
      kp = row['kp'] ?? row['estimated_kp'];
    }
    if (time == null) continue;
    final when = DateTime.tryParse('${time.replaceFirst(' ', 'T')}Z');
    final value = kp is num ? kp.toDouble() : double.tryParse('$kp');
    if (when == null || value == null) continue; // Skips the header row.
    if (when.isAfter(now.subtract(const Duration(hours: 3))) && when.isBefore(soon)) {
      maxKp = math.max(maxKp, value);
    }
  }

  // A common rule of thumb: auroras reach the horizon at a magnetic
  // latitude of about 66.5° minus 2° for each step of Kp.
  final needed = ((66.5 - magneticLatitude(lat, lon).abs()) / 2).clamp(0.0, 9.0);
  return AuroraOutlook(maxKp: maxKp, kpNeeded: needed);
}
