import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dashboard.dart';
import 'places.dart';
import 'search_page.dart';
import 'sky.dart';
import 'theme.dart';
import 'weather.dart';

void main() => runApp(const WeatherApp());

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather Dash',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system, // Follow the Windows light/dark setting.
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
  static const _defaultPlace = Place(
    name: 'Témiscaming',
    region: 'Quebec',
    country: 'Canada',
    latitude: 46.72,
    longitude: -79.10,
  );

  Timer? _timer;

  // What the person has chosen.
  Place _place = _defaultPlace;
  bool _fahrenheit = false;

  // What's on screen. The report and the place it belongs to are kept
  // together, so the name at the top always matches the numbers below it,
  // even while a different city is loading.
  WeatherReport? _report;
  Place _reportPlace = _defaultPlace;
  String? _error;
  bool _loading = true;

  // Counts requests, so a slow old answer can't overwrite a newer one.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _start();
    // Fetch fresh data every 15 minutes, so the dashboard can stay open.
    _timer = Timer.periodic(const Duration(minutes: 15), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// On startup: load saved settings first, then fetch the weather.
  Future<void> _start() async {
    await _loadSettings();
    await _load();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = SharedPreferencesAsync();
      final savedPlace = await prefs.getString('place');
      final savedFahrenheit = await prefs.getBool('fahrenheit');
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

  /// Saves one setting. If saving fails, the app carries on without it.
  Future<void> _save(Future<void> Function(SharedPreferencesAsync prefs) write) async {
    try {
      await write(SharedPreferencesAsync());
    } catch (_) {
      // Not being able to save a setting isn't worth interrupting anyone for.
    }
  }

  /// Fetches the weather for the chosen place and units. Whatever is on
  /// screen stays there until the new answer arrives.
  Future<void> _load() async {
    final id = ++_requestId;
    final place = _place;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final report = await fetchWeather(
        place.latitude,
        place.longitude,
        fahrenheit: _fahrenheit,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _report = report;
        _reportPlace = place;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _toggleUnits() {
    setState(() => _fahrenheit = !_fahrenheit);
    _save((prefs) => prefs.setBool('fahrenheit', _fahrenheit));
    _load();
  }

  Future<void> _openSearch() async {
    final picked = await Navigator.push<Place>(
      context,
      MaterialPageRoute(builder: (_) => const CitySearchPage()),
    );
    if (picked == null || !mounted) return; // They went back without choosing.
    setState(() => _place = picked);
    _save((prefs) => prefs.setString('place', jsonEncode(picked.toJson())));
    _load();
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
        SnackBar(content: Text("Couldn't open $url")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    // Keyboard shortcuts: F5 or Ctrl+R refreshes, Ctrl+F finds a city.
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _load,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): _load,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearch,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    SkyHeader(
                      placeLabel: report == null ? _place.label : _reportPlace.label,
                      report: report,
                      fahrenheit: _fahrenheit,
                      errorMessage: _error,
                      onSearch: _openSearch,
                      onToggleUnits: _toggleUnits,
                      onRefresh: _load,
                    ),
                    if (report != null)
                      GroundSections(
                        report: report,
                        fahrenheit: report.tempUnit == '°F',
                        onOpenLink: _openLink,
                      ),
                  ],
                ),
              ),
              // A thin bar along the top while fresh data is on its way.
              if (_loading && report != null)
                const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    color: Colors.white,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
