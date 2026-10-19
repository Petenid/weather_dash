import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'air_quality.dart';
import 'alerts.dart';
import 'app_state.dart';
import 'aurora.dart';
import 'comparison.dart';
import 'dashboard.dart';
import 'insights.dart';
import 'location.dart';
import 'mini_view.dart';
import 'models.dart';
import 'normals.dart';
import 'offline_cache.dart';
import 'places.dart';
import 'platform.dart';
import 'radar.dart';
import 'search_page.dart';
import 'settings.dart';
import 'share_image.dart';
import 'sky.dart';
import 'strings.dart';
import 'theme.dart';
import 'updates.dart';
import 'weather.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await loadSettings(); // Before the first frame, so the theme is right from the start.
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds when the settings change, so a new theme applies at once.
    return ValueListenableBuilder<AppSettings>(
      valueListenable: settings,
      builder: (context, s, _) => MaterialApp(
        title: 'Weather Dash',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: s.themeMode,
        // Canadian English or Canadian French. This also translates
        // Flutter's own text, such as "Back" and "Cancel" on buttons.
        locale: s.french ? const Locale('fr', 'CA') : const Locale('en', 'CA'),
        supportedLocales: const [Locale('en', 'CA'), Locale('fr', 'CA')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomePage(),
      ),
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
    region: 'Québec', // Written with the accent in both languages.
    country: 'Canada',
    latitude: 46.72,
    longitude: -79.10,
  );

  Timer? _timer;
  final _skyKey = GlobalKey(); // For taking a picture of the sky.

  // What the person has chosen.
  Place _place = _defaultPlace;
  bool _fahrenheit = false;
  List<Place> _favourites = [];
  bool _mini = false;

  // What's on screen. The report and the place it belongs to are kept
  // together, so the name at the top always matches the numbers below it,
  // even while a different city is loading.
  WeatherReport? _report;
  Place _reportPlace = _defaultPlace;
  String? _error;
  bool _loading = true;

  // Extras that load on their own, so a slow or failed one never holds up
  // the main forecast. Each remembers which place it belongs to.
  ModelComparison? _models;
  Place? _modelsPlace;
  String? _modelsError;
  AirQuality? _air;
  Place? _airPlace;
  String? _airError;
  Normals? _normals;
  Place? _normalsPlace;
  List<WeatherAlert> _alerts = const [];
  Place? _alertsPlace;
  AuroraOutlook? _aurora;
  Place? _auroraPlace;
  UpdateInfo? _update;

  // Counts requests, so a slow old answer can't overwrite a newer one.
  int _requestId = 0;

  // The settings the current data was fetched with.
  String _windUnit = settings.value.windUnit;
  bool _french = settings.value.french;
  int _refreshMinutes = settings.value.refreshMinutes;

  // Tells us when the window goes to the background and comes back.
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    settings.addListener(_settingsChanged);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) => appInForeground.value = state == AppLifecycleState.resumed,
    );
    _start();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    settings.removeListener(_settingsChanged);
    super.dispose();
  }

  /// Fetches fresh data on a schedule (every 15 minutes, or every hour in
  /// power saver), so the dashboard can stay open.
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(Duration(minutes: _refreshMinutes), (_) => _load());
  }

  /// On startup: saved choices first, then the offline copy so something
  /// shows straight away, then fresh data.
  Future<void> _start() async {
    await _loadSavedChoices();
    await _showOfflineCopy();
    if (settings.value.startAtMyLocation) {
      try {
        final here = await locateMe();
        if (mounted) setState(() => _place = here);
      } catch (_) {
        // Fall back to the last place quietly; the search page explains
        // location problems when someone asks for them directly.
      }
    }
    await _load();
    _checkForUpdate();
  }

  Future<void> _loadSavedChoices() async {
    try {
      final prefs = SharedPreferencesAsync();
      final savedPlace = await prefs.getString('place');
      final savedFahrenheit = await prefs.getBool('fahrenheit');
      final savedFavourites = await prefs.getString('favourites');
      if (!mounted) return;
      setState(() {
        if (savedPlace != null) {
          _place = Place.fromJson(jsonDecode(savedPlace) as Map<String, dynamic>);
        }
        _fahrenheit = savedFahrenheit ?? false;
        if (savedFavourites != null) {
          _favourites = [
            for (final f in jsonDecode(savedFavourites) as List)
              Place.fromJson(f as Map<String, dynamic>),
          ];
        }
      });
    } catch (_) {
      // If the saved choices can't be read, just keep the defaults.
    }
  }

  /// Shows the last forecast that was saved, if it's for the same place and
  /// units, while fresh data loads.
  Future<void> _showOfflineCopy() async {
    final cached = await loadForecast();
    if (cached == null || !mounted || _report != null) return;
    if (!cached.place.sameAs(_place) || cached.fahrenheit != _fahrenheit) return;
    try {
      final report = parseForecast(
        cached.json,
        fahrenheit: cached.fahrenheit,
        windUnit: cached.windUnit,
      );
      setState(() {
        _report = report;
        _reportPlace = _place;
      });
    } catch (_) {
      // A damaged copy is simply ignored.
    }
  }

  /// Saves one choice. If saving fails, the app carries on without it.
  Future<void> _save(Future<void> Function(SharedPreferencesAsync prefs) write) async {
    try {
      await write(SharedPreferencesAsync());
    } catch (_) {
      // Not being able to save a setting isn't worth interrupting anyone for.
    }
  }

  void _settingsChanged() {
    final s = settings.value;
    if (s.refreshMinutes != _refreshMinutes) {
      _refreshMinutes = s.refreshMinutes;
      _startTimer();
    }
    // A new wind unit or language needs new data (alerts and place names
    // come in the chosen language); other settings only need a redraw.
    if (s.windUnit != _windUnit || s.french != _french) {
      _french = s.french;
      _load();
    } else {
      setState(() {});
    }
  }

  /// Fetches the weather for the chosen place and units. Whatever is on
  /// screen stays there until the new answer arrives.
  Future<void> _load() async {
    final id = ++_requestId;
    final place = _place;
    final fahrenheit = _fahrenheit;
    final windUnit = settings.value.windUnit;
    setState(() {
      _loading = true;
      _error = null;
      _modelsError = null;
      _airError = null;
    });
    _loadExtras(id, place, fahrenheit);

    try {
      final json = await fetchForecastJson(
        place.latitude,
        place.longitude,
        fahrenheit: fahrenheit,
        windUnit: windUnit,
      );
      final report = parseForecast(json, fahrenheit: fahrenheit, windUnit: windUnit);
      if (!mounted || id != _requestId) return;
      setState(() {
        _report = report;
        _reportPlace = place;
        _windUnit = windUnit;
        _loading = false;
      });
      saveForecast(CachedForecast(
        place: place,
        fahrenheit: fahrenheit,
        windUnit: windUnit,
        json: json,
      ));
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  /// Starts every extra at once. Each one updates the screen when it's ready.
  void _loadExtras(int id, Place place, bool fahrenheit) {
    final lat = place.latitude, lon = place.longitude;

    // Runs [update] only if this is still the newest request.
    void ifCurrent(VoidCallback update) {
      if (mounted && id == _requestId) setState(update);
    }

    fetchModelComparison(lat, lon, fahrenheit: fahrenheit).then(
      (m) => ifCurrent(() {
        _models = m;
        _modelsPlace = place;
      }),
      onError: (Object e) => ifCurrent(() => _modelsError = friendlyError(e)),
    );

    fetchAirQuality(lat, lon).then(
      (a) => ifCurrent(() {
        _air = a;
        _airPlace = place;
      }),
      onError: (Object e) => ifCurrent(() => _airError = friendlyError(e)),
    );

    // Without normals, alerts or the aurora outlook, those parts are simply
    // left out, so their errors are ignored.
    fetchNormals(lat, lon, DateTime.now(), fahrenheit: fahrenheit).then(
      (n) => ifCurrent(() {
        _normals = n;
        _normalsPlace = place;
      }),
      onError: (Object _) {},
    );

    fetchAlerts(lat, lon).then(
      (a) => ifCurrent(() {
        _alerts = a;
        _alertsPlace = place;
      }),
      onError: (Object _) {},
    );

    if (auroraRelevant(lat, lon)) {
      fetchAuroraOutlook(lat, lon).then(
        (a) => ifCurrent(() {
          _aurora = a;
          _auroraPlace = place;
        }),
        onError: (Object _) {},
      );
    }
  }

  Future<void> _checkForUpdate() async {
    try {
      final update = await checkForUpdate();
      if (update != null && mounted) setState(() => _update = update);
    } catch (_) {
      // Checking for updates is a nicety; failures stay quiet.
    }
  }

  /// The place whose weather is on screen right now.
  Place get _shownPlace => _report == null ? _place : _reportPlace;

  void _choosePlace(Place place) {
    setState(() => _place = place);
    _save((prefs) => prefs.setString('place', jsonEncode(place.toJson())));
    _load();
  }

  /// Saves the place on screen, or removes it if it's already saved.
  void _toggleFavourite() {
    final place = _shownPlace;
    setState(() {
      if (_favourites.any((f) => f.sameAs(place))) {
        _favourites = [for (final f in _favourites) if (!f.sameAs(place)) f];
      } else {
        // Keep at most 10, dropping the oldest.
        _favourites = [..._favourites, place];
        if (_favourites.length > 10) _favourites = _favourites.sublist(1);
      }
    });
    final json = jsonEncode([for (final f in _favourites) f.toJson()]);
    _save((prefs) => prefs.setString('favourites', json));
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
    _choosePlace(picked);
  }

  Future<void> _toggleMini() async {
    final on = !_mini;
    setState(() => _mini = on);
    await setMiniWindow(on);
  }

  void _showMessage(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _onMenu(SkyMenuAction action) async {
    switch (action) {
      case SkyMenuAction.copyImage:
        try {
          await copyImage(_skyKey);
          _showMessage(t.copied);
        } catch (_) {
          _showMessage(t.copyFailed);
        }
      case SkyMenuAction.saveImage:
        try {
          if (await saveImage(_skyKey, t.imageName(_shownPlace.name))) _showMessage(t.saved);
        } catch (_) {
          _showMessage(t.saveFailed);
        }
      case SkyMenuAction.miniMode:
        await _toggleMini();
      case SkyMenuAction.settings:
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        );
    }
  }

  Future<void> _openLink(String url) async {
    var opened = false;
    try {
      opened = await launchUrl(Uri.parse(url));
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) _showMessage(t.couldNotOpen(url));
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    final shown = _shownPlace;

    // Only show extras that match the place (and units) on screen.
    bool matches(Place? p) => identical(p, _reportPlace);
    final models = _models;
    final modelsMatch = report != null &&
        models != null &&
        matches(_modelsPlace) &&
        models.tempUnit == report.tempUnit;
    final fahrenheitShown = report?.tempUnit == '°F';

    final shortcuts = <ShortcutActivator, VoidCallback>{
      const SingleActivator(LogicalKeyboardKey.f5): _load,
      const SingleActivator(LogicalKeyboardKey.keyR, control: true): _load,
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): _openSearch,
      const SingleActivator(LogicalKeyboardKey.keyD, control: true): _toggleFavourite,
      if (desktopFeatures) const SingleActivator(LogicalKeyboardKey.keyM, control: true): _toggleMini,
    };

    if (_mini) {
      return CallbackShortcuts(
        bindings: shortcuts,
        child: Focus(
          autofocus: true,
          child: MiniView(placeLabel: shown.label, report: report, onExit: _toggleMini),
        ),
      );
    }

    return CallbackShortcuts(
      bindings: shortcuts,
      child: Focus(
        autofocus: true,
        child: Scaffold(
          body: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    RepaintBoundary(
                      key: _skyKey,
                      child: SkyHeader(
                        placeLabel: shown.label,
                        report: report,
                        fahrenheit: _fahrenheit,
                        errorMessage: _error,
                        onSearch: _openSearch,
                        onToggleUnits: _toggleUnits,
                        onRefresh: _load,
                        favourites: _favourites,
                        currentPlace: shown,
                        isFavourite: _favourites.any((f) => f.sameAs(shown)),
                        onToggleFavourite: _toggleFavourite,
                        onChoosePlace: _choosePlace,
                        alerts: matches(_alertsPlace) ? _alerts : const [],
                        update: _update,
                        onMenu: _onMenu,
                        onOpenLink: _openLink,
                      ),
                    ),
                    if (report != null)
                      GroundSections(
                        report: report,
                        fahrenheit: fahrenheitShown,
                        insights: InsightsSection(
                          report: report,
                          fahrenheit: fahrenheitShown,
                          normals: matches(_normalsPlace) ? _normals : null,
                          aurora: matches(_auroraPlace) ? _aurora : null,
                          southern: shown.latitude < 0,
                        ),
                        radar: RadarSection(place: shown, onOpenLink: _openLink),
                        comparison: ModelComparisonSection(
                          comparison: modelsMatch ? models : null,
                          error: _modelsError,
                          onRetry: _load,
                        ),
                        air: matches(_airPlace) ? _air : null,
                        airError: _airError,
                        onOpenLink: _openLink,
                        latitude: shown.latitude,
                        longitude: shown.longitude,
                        refreshMinutes: _refreshMinutes,
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
