import 'dart:math' as math;

/// How high the sun is above the horizon, in degrees (negative when it's
/// below), at a moment in UTC. A standard low-precision formula, accurate to
/// well under a degree, which is plenty for photography times.
double sunElevation(double lat, double lon, DateTime utc) {
  const rad = math.pi / 180;
  final days = utc.millisecondsSinceEpoch / 86400000.0 + 2440587.5 - 2451545.0;

  // Where the sun is along its yearly path, and the tilt of the Earth.
  final meanLongitude = (280.460 + 0.9856474 * days) % 360;
  final meanAnomaly = ((357.528 + 0.9856003 * days) % 360) * rad;
  final eclipticLongitude = (meanLongitude +
          1.915 * math.sin(meanAnomaly) +
          0.020 * math.sin(2 * meanAnomaly)) *
      rad;
  final tilt = (23.439 - 0.0000004 * days) * rad;

  // The sun's position on the sky's globe...
  final rightAscension =
      math.atan2(math.cos(tilt) * math.sin(eclipticLongitude), math.cos(eclipticLongitude));
  final declination = math.asin(math.sin(tilt) * math.sin(eclipticLongitude));

  // ...and how far the Earth has turned under it.
  final siderealHours = (18.697374558 + 24.06570982441908 * days) % 24;
  final hourAngle = (siderealHours * 15 + lon) * rad - rightAscension;

  final phi = lat * rad;
  final elevation = math.asin(math.sin(phi) * math.sin(declination) +
      math.cos(phi) * math.cos(declination) * math.cos(hourAngle));
  return elevation / rad;
}

/// A span of local time.
class TimeSpan {
  final DateTime start;
  final DateTime end;
  const TimeSpan(this.start, this.end);
}

/// The soft-light times photographers look for, on one day.
/// Golden hour: the sun between 6° above and 4° below the horizon.
/// Blue hour: the sun between 4° and 6° below the horizon.
/// Any of these can be missing near the poles.
class PhotoTimes {
  final TimeSpan? morningBlue;
  final TimeSpan? morningGolden;
  final TimeSpan? eveningGolden;
  final TimeSpan? eveningBlue;

  const PhotoTimes({this.morningBlue, this.morningGolden, this.eveningGolden, this.eveningBlue});

  bool get isEmpty =>
      morningBlue == null && morningGolden == null && eveningGolden == null && eveningBlue == null;
}

/// Works out [PhotoTimes] for a place on a local calendar [day], where local
/// time is [utcOffset] from UTC. Checks the sun every 2 minutes.
PhotoTimes photoTimes(double lat, double lon, DateTime day, Duration utcOffset) {
  const step = Duration(minutes: 2);
  final startUtc = DateTime.utc(day.year, day.month, day.day).subtract(utcOffset);
  const steps = 24 * 30;

  // 0 = night or full day, 1 = blue hour, 2 = golden hour.
  int band(double e) => e >= -6 && e < -4 ? 1 : (e >= -4 && e < 6 ? 2 : 0);

  final elevations = [for (var i = 0; i <= steps; i++) sunElevation(lat, lon, startUtc.add(step * i))];
  var noon = 0;
  for (var i = 1; i < elevations.length; i++) {
    if (elevations[i] > elevations[noon]) noon = i;
  }

  // The local time for step i, written as a plain (time-zone-free) DateTime.
  DateTime local(int i) {
    final x = startUtc.add(step * i).add(utcOffset);
    return DateTime(x.year, x.month, x.day, x.hour, x.minute);
  }

  // Finds the first run of [wanted] in steps from..to (inclusive).
  TimeSpan? run(int wanted, int from, int to, {bool last = false}) {
    int? s, e;
    final range = [for (var i = from; i <= to; i++) i];
    for (final i in last ? range.reversed : range) {
      if (band(elevations[i]) == wanted) {
        if (last) {
          e ??= i;
          s = i;
        } else {
          s ??= i;
          e = i;
        }
      } else if (s != null) {
        break;
      }
    }
    if (s == null || e == null) return null;
    return TimeSpan(local(s), local(e + 1));
  }

  return PhotoTimes(
    morningBlue: run(1, 0, noon),
    morningGolden: run(2, 0, noon),
    eveningGolden: run(2, noon, steps, last: true),
    eveningBlue: run(1, noon, steps, last: true),
  );
}
