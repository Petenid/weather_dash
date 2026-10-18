import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'weather.dart';

const _latitude = 46.72;
const _longitude = -79.10;
const _placeName = 'Témiscaming, QC';

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
  late Future<WeatherReport> _weather;

  @override
  void initState() {
    super.initState();
    _weather = fetchWeather(_latitude, _longitude);
  }

  void _refresh() {
    setState(() {
      _weather = fetchWeather(_latitude, _longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather Dash'),
        actions: [
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
                return Text(
                  'Could not load the weather.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                );
              }
              final report = snapshot.data!;
              return Column(
                mainAxisSize: MainAxisSize.min,
                                children: [
                  CurrentConditionsCard(
                    place: _placeName,
                    weather: report.current,
                  ),
                  const SizedBox(height: 16),
                  HourlyChartCard(hours: report.hourly),
                  const SizedBox(height: 16),
                  DailyForecastCard(days: report.daily),
                ],
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Weather data by Open-Meteo.com',
          textAlign: TextAlign.center,
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
  });

  final String place;
  final CurrentWeather weather;

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
              Text(place, style: text.titleLarge),
              const SizedBox(height: 16),
              Icon(
                weatherIcon(weather.weatherCode, isDay: weather.isDay),
                size: 72,
              ),
              Text('${weather.temperature.round()}°C', style: text.displayLarge),
              Text(describeWeather(weather.weatherCode), style: text.titleMedium),
              const SizedBox(height: 16),
              Text('Feels like ${weather.feelsLike.round()}°C'),
              Text(
                'Wind ${weather.windSpeed.round()} km/h '
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
  const HourlyChartCard({super.key, required this.hours});

  final List<HourlyPoint> hours;

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
                              '${spot.y.toStringAsFixed(1)}°C',
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