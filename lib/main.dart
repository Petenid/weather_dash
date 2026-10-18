import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'places.dart';
import 'search_page.dart';
import 'weather.dart';

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Dash',
      theme: ThemeData(colorSchemeSeed: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _prefs = SharedPreferencesAsync();

  Place _place = const Place(
    name: 'Témiscaming',
    region: 'Quebec',
    country: 'Canada',
    latitude: 46.72,
    longitude: -79.10,
  );
  bool _fahrenheit = false;
  late Future<WeatherReport> _weather;

  @override
  void initState() {
    super.initState();
    _weather = _start();
  }

  /// On startup: load saved settings first, then fetch the weather.
  Future<WeatherReport> _start() async {
    await _loadSettings();
    return _fetch();
  }

  Future<WeatherReport> _fetch() {
    return fetchWeather(
      _place.latitude,
      _place.longitude,
      fahrenheit: _fahrenheit,
    );
  }

  Future<void> _loadSettings() async {
    try {
      final savedPlace = await _prefs.getString('place');
      final savedFahrenheit = await _prefs.getBool('fahrenheit');
      if (!mounted) return;
      setState(() {
        if (savedPlace != null) {
          _place = Place.fromJson(jsonDecode(savedPlace) as Map<String, dynamic>);
        }
        _fahrenheit = savedFahrenheit ?? false;
      });
    } catch (_) {
      // If the saved settings can't be read, just keep the defaults.
    }
  }

  void _refresh() {
    setState(() {
      _weather = _fetch();
    });
  }

  void _toggleUnits() {
    setState(() {
      _fahrenheit = !_fahrenheit;
      _weather = _fetch();
    });
    _prefs.setBool('fahrenheit', _fahrenheit);
  }

  Future<void> _openSearch() async {
    final picked = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const CitySearchPage()),
    );
    if (picked == null) return; // They went back without choosing.
    setState(() {
      _place = picked;
      _weather = _fetch();
    });
    _prefs.setString('place', jsonEncode(picked.toJson()));
  }

  Future<void> _openLink(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  Widget _link(String label, String url) {
    return TextButton(
      onPressed: () => _openLink(url),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Dash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Find a city',
            onPressed: _openSearch,
          ),
          Tooltip(
            message: _fahrenheit ? 'Switch to Celsius' : 'Switch to Fahrenheit',
            child: TextButton(
              onPressed: _toggleUnits,
              child: Text(
                _fahrenheit ? '°F' : '°C',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: FutureBuilder<WeatherReport>(
            future: _weather,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const CircularProgressIndicator();
              }
              if (snapshot.hasError) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load the weather.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('Try again'),
                    ),
                  ],
                );
              }
              final report = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CurrentConditionsCard(
                    place: _place.label,
                    weather: report.current,
                    tempUnit: report.tempUnit,
                    windUnit: report.windUnit,
                  ),
                  const SizedBox(height: 16),
                  HourlyChartCard(
                    hours: report.hourly,
                    tempUnit: report.tempUnit,
                  ),
                  const SizedBox(height: 16),
                  DailyForecastCard(days: report.daily),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(8),
        child: Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Weather data by'),
            _link('Open-Meteo.com', 'https://open-meteo.com/'),
            const Text('·  Location search by'),
            _link('GeoNames', 'https://www.geonames.org/'),
          ],
        ),
      ),
    );
  }
}

class CurrentConditionsCard extends StatelessWidget {
  const CurrentConditionsCard({
    super.key,
    required this.place,
    required this.weather,
    required this.tempUnit,
    required this.windUnit,
  });

  final String place;
  final CurrentWeather weather;
  final String tempUnit;
  final String windUnit;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(place, style: text.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Icon(
                weatherIcon(weather.weatherCode, isDay: weather.isDay),
                size: 72,
              ),
              Text('${weather.temperature.round()}$tempUnit', style: text.displayLarge),
              Text(describeWeather(weather.weatherCode), style: text.titleMedium),
              const SizedBox(height: 16),
              Text('Feels like ${weather.feelsLike.round()}$tempUnit'),
              Text(
                'Wind ${weather.windSpeed.round()} $windUnit '
                '${compassDirection(weather.windDirection)}',
              ),
              Text('Humidity ${weather.humidity}%'),
              const SizedBox(height: 12),
              Text('Updated ${_hoursMinutes(weather.time)}', style: text.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class DailyForecastCard extends StatelessWidget {
  const DailyForecastCard({super.key, required this.days});

  final List<DailyForecast> days;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('7-day forecast', style: text.titleMedium),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < days.length; i++)
                    Expanded(
                      child: _DayColumn(
                        day: days[i],
                        label: i == 0 ? 'Today' : _weekdayName(days[i].date),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({required this.day, required this.label});

  final DailyForecast day;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return Tooltip(
      message: describeWeather(day.weatherCode),
      child: Column(
        children: [
          Text(label, style: text.labelLarge),
          const SizedBox(height: 8),
          Icon(weatherIcon(day.weatherCode, isDay: true), size: 32),
          const SizedBox(height: 8),
          Text('${day.high.round()}°', style: text.titleMedium),
          Text(
            '${day.low.round()}°',
            style: text.bodyMedium?.copyWith(color: muted),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop, size: 12, color: muted),
              Text(
                '${day.precipitationChance}%',
                style: text.bodySmall?.copyWith(color: muted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _weekdayName(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[date.weekday - 1];
}

String _hoursMinutes(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

    class HourlyChartCard extends StatelessWidget {
  const HourlyChartCard({super.key, required this.hours, required this.tempUnit});

  final List<HourlyPoint> hours;
  final String tempUnit;

  @override
  Widget build(BuildContext context) {
    if (hours.isEmpty) return const SizedBox.shrink();

    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    // Give the line some breathing room above and below.
    final temps = hours.map((h) => h.temperature).toList();
    final lowest = temps.reduce((a, b) => a < b ? a : b);
    final highest = temps.reduce((a, b) => a > b ? a : b);
    final minY = (lowest - 2).floorToDouble();
    final maxY = (highest + 2).ceilToDouble();

    // One point per hour: x is the hour number (0–23), y is the temperature.
    final spots = [
      for (var i = 0; i < hours.length; i++)
        FlSpot(i.toDouble(), hours[i].temperature),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 24, 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Next 24 hours', style: text.titleMedium),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minY: minY,
                    maxY: maxY,
                    gridData: const FlGridData(drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 36,
                          interval: (maxY - minY) <= 12 ? 2 : 5,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.min || value == meta.max) {
                              return const SizedBox.shrink();
                            }
                            return Text('${value.round()}°', style: text.bodySmall);
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            // Label every third hour so the times don't crowd.
                            if (i % 3 != 0 || i >= hours.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                _hoursMinutes(hours[i].time),
                                style: text.bodySmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => colors.inverseSurface,
                        getTooltipItems: (touchedSpots) => [
                          for (final spot in touchedSpots)
                            LineTooltipItem(
                              '${_hoursMinutes(hours[spot.x.toInt()].time)}\n'
                              '${spot.y.toStringAsFixed(1)}$tempUnit',
                              TextStyle(color: colors.onInverseSurface),
                            ),
                        ],
                      ),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        preventCurveOverShooting: true,
                        color: colors.primary,
                        barWidth: 3,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: colors.primary.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}