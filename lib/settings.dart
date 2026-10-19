import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'strings.dart';
import 'weather.dart';

/// Which language to show: the system's, or a fixed choice.
enum AppLanguage { system, english, french }

/// The choices on the settings screen.
class AppSettings {
  final bool use24Hour;
  final String windUnit; // One of [windUnits].
  final ThemeMode themeMode;
  final bool startAtMyLocation;
  final AppLanguage language;
  final bool powerSaver;
  final bool pauseInBackground;

  const AppSettings({
    this.use24Hour = true,
    this.windUnit = 'kmh',
    this.themeMode = ThemeMode.system,
    this.startAtMyLocation = false,
    this.language = AppLanguage.system,
    this.powerSaver = false,
    this.pauseInBackground = true,
  });

  AppSettings copyWith({
    bool? use24Hour,
    String? windUnit,
    ThemeMode? themeMode,
    bool? startAtMyLocation,
    AppLanguage? language,
    bool? powerSaver,
    bool? pauseInBackground,
  }) {
    return AppSettings(
      use24Hour: use24Hour ?? this.use24Hour,
      windUnit: windUnit ?? this.windUnit,
      themeMode: themeMode ?? this.themeMode,
      startAtMyLocation: startAtMyLocation ?? this.startAtMyLocation,
      language: language ?? this.language,
      powerSaver: powerSaver ?? this.powerSaver,
      pauseInBackground: pauseInBackground ?? this.pauseInBackground,
    );
  }

  /// True if the app should show French right now.
  bool get french => switch (language) {
        AppLanguage.french => true,
        AppLanguage.english => false,
        AppLanguage.system => PlatformDispatcher.instance.locale.languageCode == 'fr',
      };

  /// How often to fetch fresh data, in minutes.
  int get refreshMinutes => powerSaver ? 60 : 15;
}

/// The current settings. Widgets that care (like the app's theme) listen to
/// this and rebuild when it changes.
final settings = ValueNotifier<AppSettings>(const AppSettings());

/// Copies settings into the plain flags the rest of the code reads.
void _apply(AppSettings s) {
  use24HourClock = s.use24Hour;
  frenchActive = s.french;
}

/// Reads saved settings. Missing or unreadable values keep their defaults.
Future<void> loadSettings() async {
  try {
    final prefs = SharedPreferencesAsync();
    T pick<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.firstWhere((v) => v.name == name, orElse: () => fallback);
    settings.value = AppSettings(
      use24Hour: await prefs.getBool('use24Hour') ?? true,
      windUnit: await prefs.getString('windUnit') ?? 'kmh',
      themeMode: pick(ThemeMode.values, await prefs.getString('theme'), ThemeMode.system),
      startAtMyLocation: await prefs.getBool('startAtMyLocation') ?? false,
      language: pick(AppLanguage.values, await prefs.getString('language'), AppLanguage.system),
      powerSaver: await prefs.getBool('powerSaver') ?? false,
      pauseInBackground: await prefs.getBool('pauseInBackground') ?? true,
    );
  } catch (_) {
    // Keep the defaults.
  }
  _apply(settings.value);
}

Future<void> saveSettings(AppSettings s) async {
  _apply(s);
  settings.value = s;
  try {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool('use24Hour', s.use24Hour);
    await prefs.setString('windUnit', s.windUnit);
    await prefs.setString('theme', s.themeMode.name);
    await prefs.setBool('startAtMyLocation', s.startAtMyLocation);
    await prefs.setString('language', s.language.name);
    await prefs.setBool('powerSaver', s.powerSaver);
    await prefs.setBool('pauseInBackground', s.pauseInBackground);
  } catch (_) {
    // The new settings still apply until the app closes.
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettings>(
      valueListenable: settings,
      builder: (context, s, _) {
        final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
        return Scaffold(
          appBar: AppBar(title: Text(t.settings)),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  _Heading(t.language),
                  SegmentedButton<AppLanguage>(
                    segments: [
                      ButtonSegment(value: AppLanguage.system, label: Text(t.matchSystem)),
                      const ButtonSegment(value: AppLanguage.english, label: Text('English')),
                      const ButtonSegment(value: AppLanguage.french, label: Text('Français')),
                    ],
                    selected: {s.language},
                    onSelectionChanged: (v) => saveSettings(s.copyWith(language: v.first)),
                  ),
                  _Heading(t.clock),
                  SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(value: true, label: Text(t.clock24)),
                      ButtonSegment(value: false, label: Text(t.clock12)),
                    ],
                    selected: {s.use24Hour},
                    onSelectionChanged: (v) => saveSettings(s.copyWith(use24Hour: v.first)),
                  ),
                  _Heading(t.windSpeed),
                  SegmentedButton<String>(
                    segments: [
                      for (final unit in windUnits)
                        ButtonSegment(value: unit, label: Text(t.windUnitLabel(unit))),
                    ],
                    selected: {s.windUnit},
                    onSelectionChanged: (v) => saveSettings(s.copyWith(windUnit: v.first)),
                  ),
                  _Heading(t.appearance),
                  SegmentedButton<ThemeMode>(
                    segments: [
                      ButtonSegment(value: ThemeMode.system, label: Text(t.matchSystem)),
                      ButtonSegment(value: ThemeMode.light, label: Text(t.light)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(t.dark)),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) => saveSettings(s.copyWith(themeMode: v.first)),
                  ),
                  _Heading(t.powerSaving),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.powerSaver),
                    subtitle: Text(t.powerSaverHelp),
                    value: s.powerSaver,
                    onChanged: (v) => saveSettings(s.copyWith(powerSaver: v)),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.pauseInBackground),
                    subtitle: Text(t.pauseInBackgroundHelp),
                    value: s.pauseInBackground,
                    onChanged: s.powerSaver
                        ? null // Power saver already stops the animation.
                        : (v) => saveSettings(s.copyWith(pauseInBackground: v)),
                  ),
                  _Heading(t.onOpen),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(t.startHere),
                    subtitle: Text(t.startHereHelp),
                    value: s.startAtMyLocation,
                    onChanged: (v) => saveSettings(s.copyWith(startAtMyLocation: v)),
                  ),
                  const SizedBox(height: 24),
                  Text(t.tempUnitsNote, style: muted),
                ],
              ),
            ),
          ),
        );
      },
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
