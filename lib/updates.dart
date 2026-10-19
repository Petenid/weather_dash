import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// This copy's version. GitHub Actions fills it in when it builds a release
/// (see the --dart-define in the build workflow). Copies run from VS Code
/// say "dev" and never check for updates.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'dev');

/// A newer release on GitHub.
class UpdateInfo {
  final String version;
  final String url;

  const UpdateInfo({required this.version, required this.url});
}

/// Returns the newest release if it's newer than this copy, otherwise null.
Future<UpdateInfo?> checkForUpdate() async {
  // The web version is always the newest, and copies run from VS Code
  // have no version to compare.
  if (kIsWeb || appVersion == 'dev') return null;
  final uri = Uri.https('api.github.com', '/repos/Petenid/weather_dash/releases/latest');
  final response = await http
      .get(uri, headers: {'Accept': 'application/vnd.github+json'})
      .timeout(const Duration(seconds: 10));
  if (response.statusCode != 200) return null;

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final latest = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
  if (!isNewer(latest, appVersion)) return null;
  return UpdateInfo(version: latest, url: data['html_url'] as String? ?? '');
}

/// True if version [a] (like "1.2.0") is newer than [b].
bool isNewer(String a, String b) {
  List<int> parts(String v) => [for (final p in v.split('.')) int.tryParse(p) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final xi = i < x.length ? x[i] : 0;
    final yi = i < y.length ? y[i] : 0;
    if (xi != yi) return xi > yi;
  }
  return false;
}
