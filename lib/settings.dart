import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'weather.dart';

/// The choices on the settings screen.
class AppSettings {
  final bool use24Hour;
  final String windUnit; // One of the keys in [windUnits].
  final ThemeMode themeMode;
  final bool startAtMyLocation;

  const AppSettings({
    this.use24Hour = true,
    this.windUnit = 'kmh',
    this.themeMode = ThemeMode.system,
    this.startAtMyLocation = false,
  });

  AppSettings copyWith({
    bool? use24Hour,
    String? windUnit,
    ThemeMode? themeMode,
    bool? startAtMyLocation,
  }) {
    return AppSettings(
      use24Hour: use24Hour ?? this.use24Hour,
      windUnit: windUnit ?? this.windUnit,
      themeMode: themeMode ?? this.themeMode,
      startAtMyLocation: startAtMyLocation ?? this.startAtMyLocation,
    );
  }
}

/// The current settings. Widgets that care (like the app's theme) listen to
/// this and rebuild when it changes.
final settings = ValueNotifier<AppSettings>(const AppSettings());

/// Reads saved settings. Missing or unreadable values keep their defaults.
Future<void> loadSettings() async {
  try {
    final prefs = SharedPreferencesAsync();
    final theme = await prefs.getString('theme');
    settings.value = AppSettings(
      use24Hour: await prefs.getBool('use24Hour') ?? true,
      windUnit: await prefs.getString('windUnit') ?? 'kmh',
      themeMode: ThemeMode.values.firstWhere(
        (m) => m.name == theme,
        orElse: () => ThemeMode.system,
      ),
      startAtMyLocation: await prefs.getBool('startAtMyLocation') ?? false,
    );
  } catch (_) {
    // Keep the defaults.
  }
  use24HourClock = settings.value.use24Hour;
}

Future<void> _saveSettings(AppSettings s) async {
  settings.value = s;
  use24HourClock = s.use24Hour;
  try {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('use24Hour', s.use24Hour);
    await prefs.setString('windUnit', s.windUnit);
    await prefs.setString('theme', s.themeMode.name);
    await prefs.setBool('startAtMyLocation', s.startAtMyLocation);
  } catch (_) {
    // The new settings still apply until the app closes.
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ValueListenableBuilder<AppSettings>(
        valueListenable: settings,
        builder: (context, s, _) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Heading('Clock'),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('24-hour (13:00)')),
                      ButtonSegment(value: false, label: Text('12-hour (1 pm)')),
                    ],
                    selected: {s.use24Hour},
                    onSelectionChanged: (v) => _saveSettings(s.copyWith(use24Hour: v.first)),
                  ),
                  _Heading('Wind speed'),
                  SegmentedButton<String>(
                    segments: [
                      for (final e in windUnits.entries)
                        ButtonSegment(value: e.key, label: Text(e.value)),
                    ],
                    selected: {s.windUnit},
                    onSelectionChanged: (v) => _saveSettings(s.copyWith(windUnit: v.first)),
                  ),
                  _Heading('Appearance'),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Match Windows')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => _saveSettings(s.copyWith(themeMode: v.first)),
                  ),
                  _Heading('When Weather Dash opens'),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show the weather where I am'),
                    subtitle: const Text(
                      'Uses Windows location services. When this is off, '
                      'Weather Dash opens on the last place you looked at.',
                    ),
                    value: s.startAtMyLocation,
                    onChanged: (v) => _saveSettings(s.copyWith(startAtMyLocation: v)),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Temperature units are switched with the °C / °F button on the main screen.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 10),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}
