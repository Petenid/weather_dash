// Checks that each screen builds, in English and in French, on a desktop
// window and on a phone-sized screen. If any text or layout overflows its
// space, Flutter reports an error and the test fails.
//
// Run with:  flutter test

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:weather_dash/alerts.dart';
import 'package:weather_dash/aurora.dart';
import 'package:weather_dash/comparison.dart';
import 'package:weather_dash/dashboard.dart';
import 'package:weather_dash/day_details.dart';
import 'package:weather_dash/feels.dart';
import 'package:weather_dash/insights.dart';
import 'package:weather_dash/mini_view.dart';
import 'package:weather_dash/normals.dart';
import 'package:weather_dash/places.dart';
import 'package:weather_dash/settings.dart';
import 'package:weather_dash/sky.dart';
import 'package:weather_dash/solar.dart';
import 'package:weather_dash/strings.dart';
import 'package:weather_dash/theme.dart';
import 'package:weather_dash/weather.dart';

/// A real-shaped Open-Meteo answer for Témiscaming, saved in test/fixtures.
WeatherReport sampleReport() => parseForecast(
      File('test/fixtures/forecast_temiscaming.json').readAsStringSync(),
      fahrenheit: false,
      windUnit: 'kmh',
    );

const temiscaming = Place(
  name: 'Témiscaming',
  region: 'Québec',
  country: 'Canada',
  latitude: 46.72,
  longitude: -79.10,
);

/// Puts a widget on a scrolling page inside the app's theme and language.
Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: buildTheme(brightness),
    locale: frenchActive ? const Locale('fr', 'CA') : const Locale('en', 'CA'),
    supportedLocales: const [Locale('en', 'CA'), Locale('fr', 'CA')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Sets the test screen size.
void screen(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

void main() {
  tearDown(() {
    frenchActive = false;
    use24HourClock = true;
  });

  test('reads a real-shaped forecast', () {
    final r = sampleReport();
    expect(r.allHours.length, 168);
    expect(r.daily.length, 7);
    expect(r.utcOffset, const Duration(hours: -4));
    expect(r.next24Hours.first.time.hour, 20);
    expect(r.hoursOn(DateTime(2026, 10, 20)).length, 24);
    expect(r.current.temperature, 2.5);
  });

  for (final french in [false, true]) {
    final lang = french ? 'French' : 'English';

    for (final (name, width) in [('desktop', 1280.0), ('phone', 400.0)]) {
      testWidgets('top of the screen, $lang, $name', (tester) async {
        frenchActive = french;
        screen(tester, width, 1000);
        await tester.pumpWidget(wrap(SkyHeader(
          placeLabel: temiscaming.label,
          report: sampleReport(),
          fahrenheit: false,
          errorMessage: null,
          onSearch: () {},
          onToggleUnits: () {},
          onRefresh: () {},
          favourites: const [temiscaming],
          currentPlace: temiscaming,
          isFavourite: true,
          onToggleFavourite: () {},
          onChoosePlace: (_) {},
          alerts: [
            WeatherAlert(
              name: french ? 'Avertissement de gel' : 'Frost advisory',
              area: 'Témiscamingue',
              text: '',
              colour: 'yellow',
              expires: DateTime(2026, 10, 19, 9),
            ),
          ],
          update: null,
          onMenu: (_) {},
          onOpenLink: (_) {},
        )));
        await tester.pump();
        expect(find.text('Témiscaming, Québec'), findsOneWidget);
        expect(find.text(t.feelsLike('−1°')), findsOneWidget);
      });

      testWidgets('lower half of the screen, $lang, $name', (tester) async {
        frenchActive = french;
        screen(tester, width, 3000);
        final report = sampleReport();
        await tester.pumpWidget(wrap(GroundSections(
          report: report,
          fahrenheit: false,
          insights: InsightsSection(
            report: report,
            fahrenheit: false,
            normals: const Normals(high: 9, low: 0),
            aurora: const AuroraOutlook(maxKp: 5.5, kpNeeded: 5.3),
            southern: false,
          ),
          radar: const SizedBox(height: 380), // The live map isn't tested here.
          comparison: const ModelComparisonSection(comparison: null, error: null, onRetry: _nothing),
          air: null,
          airError: null,
          onOpenLink: (_) {},
          latitude: temiscaming.latitude,
          longitude: temiscaming.longitude,
        )));
        await tester.pump();
        expect(find.text(t.sevenDay), findsOneWidget);
        expect(find.text(t.atAGlance), findsOneWidget);
        expect(find.text(t.lightForPhotos), findsOneWidget);
      });
    }

    testWidgets('day details, $lang', (tester) async {
      frenchActive = french;
      screen(tester, 1280, 1400);
      final report = sampleReport();
      await tester.pumpWidget(wrap(DayDetailsDialog(
        report: report,
        initialIndex: 1,
        latitude: temiscaming.latitude,
        longitude: temiscaming.longitude,
      )));
      await tester.pump();
      expect(find.text(t.fullDate(report.daily[1].date)), findsOneWidget);

      await tester.tap(find.byTooltip(t.nextDay));
      await tester.pump();
      expect(find.text(t.fullDate(report.daily[2].date)), findsOneWidget);
    });

    testWidgets('mini mode, $lang', (tester) async {
      frenchActive = french;
      screen(tester, 360, 320);
      await tester.pumpWidget(MaterialApp(
        theme: buildTheme(Brightness.light),
        home: MiniView(placeLabel: temiscaming.label, report: sampleReport(), onExit: () {}),
      ));
      await tester.pump();
      expect(find.text('3°'), findsOneWidget);
    });

    testWidgets('dark mode builds, $lang', (tester) async {
      frenchActive = french;
      screen(tester, 1280, 3000);
      final report = sampleReport();
      await tester.pumpWidget(wrap(
        DetailsPanel(report: report, air: null, airError: 'offline'),
        brightness: Brightness.dark,
      ));
      await tester.pump();
      expect(find.text(t.unavailable), findsOneWidget);
    });
  }

  testWidgets('switching the language in settings changes the text', (tester) async {
    screen(tester, 1280, 1400);
    settings.value = const AppSettings(language: AppLanguage.english);
    frenchActive = false;
    await tester.pumpWidget(wrap(const SizedBox(height: 1400, child: SettingsPage())));
    expect(find.text('Settings'), findsOneWidget);

    await tester.tap(find.text('Français'));
    await tester.pump();
    expect(find.text('Paramètres'), findsOneWidget);
    settings.value = const AppSettings();
  });

  group('French formatting, Quebec style', () {
    setUp(() => frenchActive = true);

    test('times', () {
      expect(hoursMinutes(DateTime(2026, 1, 1, 13, 5)), '13 h 05');
      expect(hoursMinutes(DateTime(2026, 1, 1, 7, 0)), '7 h');
    });

    test('numbers, percentages and dates', () {
      expect(t.decimal(1.5, 1), '1,5');
      expect(t.percent(60), '60 %');
      expect(t.dayMonth(DateTime(2026, 10, 1)), '1er octobre');
      expect(t.fullDate(DateTime(2026, 10, 22)), 'jeudi 22 octobre');
    });

    test('weather words and compass', () {
      expect(t.describeWeather(66), 'Faible pluie verglaçante');
      expect(compassDirection(270), 'O');
      expect(t.fromDirection('est'), "De l'est");
      expect(t.fromDirection('nord-ouest'), 'Du nord-ouest');
    });
  });

  group('wind chill and humidex', () {
    test("matches Environment Canada's tables", () {
      // -20 °C with 30 km/h of wind feels like about -33.
      expect(windChillC(-20, 30), closeTo(-32.6, 0.5));
      // No wind chill when it's mild or calm.
      expect(windChillC(15, 30), isNull);
      expect(windChillC(-5, 2), isNull);
      // 30 °C at 70% humidity gives a humidex of about 41.
      expect(humidexC(30, 70), closeTo(41, 1));
      expect(humidexC(15, 90), isNull);
    });

    test('converts wind units', () {
      expect(toKmh(10, 'ms'), 36);
      expect(toKmh(10, 'kmh'), 10);
    });
  });

  group('sun position', () {
    test('the sun is high at midsummer noon in Toronto', () {
      // Solar noon in Toronto on 21 June is around 17:20 UTC.
      expect(sunElevation(43.65, -79.38, DateTime.utc(2026, 6, 21, 17, 20)), closeTo(69.8, 1.0));
      // And well below the horizon at midnight.
      expect(sunElevation(43.65, -79.38, DateTime.utc(2026, 6, 21, 5, 20)), lessThan(-20));
    });

    test('golden hour comes before blue hour in the evening', () {
      final p = photoTimes(46.72, -79.10, DateTime(2026, 10, 18), const Duration(hours: -4));
      expect(p.eveningGolden, isNotNull);
      expect(p.eveningBlue, isNotNull);
      expect(p.eveningGolden!.end.isAfter(p.eveningGolden!.start), isTrue);
      expect(p.eveningBlue!.start.isBefore(p.eveningGolden!.start), isFalse);
      // In mid-October the evening golden hour starts around 17:00 in Témiscaming.
      expect(p.eveningGolden!.start.hour, inInclusiveRange(16, 18));
    });
  });
}

void _nothing() {}
