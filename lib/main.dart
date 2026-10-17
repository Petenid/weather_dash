import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '46.72',
      'longitude': '-79.10',
      'current': 'temperature_2m,apparent_temperature,weather_code,wind_speed_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
      'timezone': 'auto',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) {
        setState(() => _status = 'Error ${response.statusCode}: ${response.body}');
        return;
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final temp = data['current']['temperature_2m'];
      final pretty = const JsonEncoder.withIndent('  ').convert(data);
      setState(() => _status = 'Témiscaming right now: $temp °C\n\n$pretty');
    } catch (e) {
      setState(() => _status = 'Request failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weather Dash')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          _status,
          style: const TextStyle(fontFamily: 'Consolas'),
        ),
      ),
    );
  }
}