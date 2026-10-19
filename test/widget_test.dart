// Small checks for the helper functions. Run them with:  flutter test
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_dash/places.dart';
import 'package:weather_dash/theme.dart';
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
}
