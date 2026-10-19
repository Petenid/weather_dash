// Small checks for the helper functions. Run them with:  flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_dash/air_quality.dart';
import 'package:weather_dash/aurora.dart';
import 'package:weather_dash/moon.dart';
import 'package:weather_dash/places.dart';
import 'package:weather_dash/theme.dart';
import 'package:weather_dash/updates.dart';
import 'package:weather_dash/weather.dart';

void main() {
  test('degrees rounds and uses a real minus sign', () {
    expect(degrees(2.5), '3°');
    expect(degrees(-3.4), '−3°');
    expect(degrees(-0.4), '0°');
  });

  test('compass directions', () {
    expect(compassDirection(0), 'N');
    expect(compassDirection(44), 'NE');
    expect(compassDirection(180), 'S');
    expect(compassDirection(350), 'N');
  });

  test('UV levels follow the WHO bands', () {
    expect(uvLevel(1), 'Low');
    expect(uvLevel(4), 'Moderate');
    expect(uvLevel(7), 'High');
    expect(uvLevel(9), 'Very high');
    expect(uvLevel(11), 'Extreme');
  });

  test('weather codes map to the right sky', () {
    expect(skyKindFor(0), SkyKind.clear);
    expect(skyKindFor(3), SkyKind.overcast);
    expect(skyKindFor(63), SkyKind.rain);
    expect(skyKindFor(73), SkyKind.snow);
    expect(skyKindFor(85), SkyKind.snow);
    expect(skyKindFor(95), SkyKind.storm);
  });

  test('a saved place loads back the same', () {
    const place = Place(
      name: 'North Bay',
      region: 'Ontario',
      country: 'Canada',
      latitude: 46.3,
      longitude: -79.46,
    );
    final copy = Place.fromJson(place.toJson());
    expect(copy.label, 'North Bay, Ontario');
    expect(copy.latitude, place.latitude);
  });

  test('Fahrenheit converts to Celsius for colours', () {
    expect(toCelsius(32, fahrenheit: true), 0);
    expect(toCelsius(10, fahrenheit: false), 10);
  });

  test('places a few metres apart count as the same place', () {
    const a = Place(name: 'A', latitude: 46.72, longitude: -79.10);
    const b = Place(name: 'B', latitude: 46.723, longitude: -79.104);
    const c = Place(name: 'C', latitude: 46.30, longitude: -79.46);
    expect(a.sameAs(b), isTrue);
    expect(a.sameAs(c), isFalse);
  });

  test('air quality categories', () {
    expect(aqiLevel(20), 'Good');
    expect(aqiLevel(75), 'Moderate');
    expect(aqiLevel(120), 'Unhealthy for sensitive groups');
    expect(aqiLevel(350), 'Hazardous');
  });

  test('next 24 hours starts at the current hour', () {
    final start = DateTime(2026, 10, 18);
    final hours = [
      for (var i = 0; i < 72; i++)
        HourlyPoint(
          time: start.add(Duration(hours: i)),
          temperature: i.toDouble(),
          precipitationChance: 0,
          precipitation: 0,
          windSpeed: 0,
          windGusts: 0,
          weatherCode: 0,
          isDay: true,
        ),
    ];
    final report = WeatherReport(
      current: CurrentWeather(
        temperature: 0,
        feelsLike: 0,
        humidity: 50,
        windSpeed: 0,
        windDirection: 0,
        weatherCode: 0,
        isDay: true,
        uvIndex: null,
        time: DateTime(2026, 10, 18, 20, 30),
      ),
      allHours: hours,
      daily: const [],
      tempUnit: '°C',
      windUnit: 'km/h',
      precipUnit: 'mm',
    );
    expect(report.next24Hours.length, 24);
    expect(report.next24Hours.first.time.hour, 20);
    expect(report.hoursOn(DateTime(2026, 10, 19)).length, 24);
  });

  test('moon phases', () {
    // 2026-07-29 was close to a full moon; 2026-08-12 close to a new moon.
    expect(MoonPhase.at(DateTime.utc(2026, 7, 29, 15)).illumination, greaterThan(0.95));
    expect(MoonPhase.at(DateTime.utc(2026, 8, 12, 18)).illumination, lessThan(0.05));
  });

  test('version comparison for updates', () {
    expect(isNewer('1.2.0', '1.1.9'), isTrue);
    expect(isNewer('1.0.0', '1.0.0'), isFalse);
    expect(isNewer('0.9.5', '1.0.0'), isFalse);
    expect(isNewer('2.0', '1.9.9'), isTrue);
  });

  test('Témiscaming is in aurora country, Miami is not', () {
    expect(magneticLatitude(46.72, -79.10), closeTo(56, 1.5));
    expect(auroraRelevant(46.72, -79.10), isTrue);
    expect(auroraRelevant(25.76, -80.19), isFalse);
  });

  test('12-hour clock', () {
    use24HourClock = false;
    expect(hoursMinutes(DateTime(2026, 1, 1, 13, 5)), '1:05 pm');
    expect(hoursMinutes(DateTime(2026, 1, 1, 0, 0)), '12 am');
    use24HourClock = true;
    expect(hoursMinutes(DateTime(2026, 1, 1, 13, 5)), '13:05');
  });
}
