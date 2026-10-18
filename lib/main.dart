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
  late Future<CurrentWeather> _weather;

  @override
  void initState() {
    super.initState();
    _weather = fetchCurrentWeather(_latitude, _longitude);
  }

  void _refresh() {
    setState(() {
      _weather = fetchCurrentWeather(_latitude, _longitude);
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
          child: FutureBuilder<CurrentWeather>(
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
              return CurrentConditionsCard(
                place: _placeName,
                weather: snapshot.data!,
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

String _hoursMinutes(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';