import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'places.dart';
import 'weather.dart';

/// Colour recipes for the base map. Each row works out one colour channel
/// (red, green, blue, opacity) from the original red, green, blue and opacity.
///
/// Muted: keeps a third of the original colour, the rest becomes grey.
const _mutedMap = <double>[
  0.488, 0.465, 0.047, 0, 0,
  0.138, 0.815, 0.047, 0, 0,
  0.138, 0.465, 0.397, 0, 0,
  0, 0, 0, 1, 0,
];

/// Dark: turns the map into greys and flips light and dark, so white land
/// becomes a dark slate and dark roads and labels become light.
const _darkMap = <double>[
  -0.159, -0.536, -0.054, 0, 215,
  -0.159, -0.536, -0.054, 0, 220,
  -0.159, -0.536, -0.054, 0, 230,
  0, 0, 0, 1, 0,
];

/// One radar picture: where to find its map tiles, and when it was taken.
class RadarFrame {
  final String path;
  final DateTime time;
  const RadarFrame(this.path, this.time);
}

/// Asks RainViewer which radar pictures are available (the last 2 hours,
/// every 10 minutes). We keep every second one so the animation loads fewer
/// map tiles.
Future<(String, List<RadarFrame>)> fetchRadarFrames() async {
  final uri = Uri.https('api.rainviewer.com', '/public/weather-maps.json');
  final response = await http.get(uri).timeout(const Duration(seconds: 15));
  if (response.statusCode != 200) {
    throw Exception('RainViewer returned error ${response.statusCode}.');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final host = data['host'] as String? ?? 'https://tilecache.rainviewer.com';
  final past = ((data['radar'] as Map<String, dynamic>?)?['past'] as List?) ?? const [];
  final frames = [
    for (final f in past)
      RadarFrame(
        (f as Map<String, dynamic>)['path'] as String,
        DateTime.fromMillisecondsSinceEpoch((f['time'] as num).toInt() * 1000),
      ),
  ];
  // Every second frame, always ending on the newest.
  final kept = <RadarFrame>[
    for (var i = frames.length - 1; i >= 0; i -= 2) frames[i],
  ].reversed.toList();
  return (host, kept);
}

/// A map of rain and snow around the place, with a play button that loops
/// through the last two hours.
class RadarSection extends StatefulWidget {
  const RadarSection({super.key, required this.place, required this.onOpenLink});

  final Place place;
  final void Function(String url) onOpenLink;

  @override
  State<RadarSection> createState() => _RadarSectionState();
}

class _RadarSectionState extends State<RadarSection> {
  String? _host;
  List<RadarFrame> _frames = const [];
  int _index = 0;
  String? _error;
  Timer? _player;
  final _map = MapController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RadarSection old) {
    super.didUpdateWidget(old);
    // Move the map when the place changes.
    if (!old.place.sameAs(widget.place)) {
      _map.move(LatLng(widget.place.latitude, widget.place.longitude), 6);
    }
  }

  @override
  void dispose() {
    _player?.cancel();
    _map.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final (host, frames) = await fetchRadarFrames();
      if (!mounted) return;
      setState(() {
        _host = host;
        _frames = frames;
        _index = frames.isEmpty ? 0 : frames.length - 1;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyError(e));
    }
  }

  void _togglePlay() {
    if (_player != null) {
      _player!.cancel();
      setState(() {
        _player = null;
        _index = _frames.length - 1; // Stop on the newest picture.
      });
      return;
    }
    setState(() {
      _player = Timer.periodic(const Duration(milliseconds: 800), (_) {
        setState(() => _index = (_index + 1) % _frames.length);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final centre = LatLng(widget.place.latitude, widget.place.longitude);
    final host = _host;
    final playing = _player != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 8,
          children: [
            Text('Radar', style: theme.textTheme.titleMedium),
            if (_frames.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    playing
                        ? hoursMinutes(_frames[_index].time)
                        : 'Latest, ${hoursMinutes(_frames[_index].time)}',
                    style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    tooltip: playing ? 'Stop' : 'Play the last two hours',
                    onPressed: _togglePlay,
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 380,
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: centre,
                initialZoom: 6,
                minZoom: 3,
                maxZoom: 9,
                // Dragging and double-click zoom, but not the mouse wheel, so
                // scrolling the page doesn't zoom the map by surprise.
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.drag |
                      InteractiveFlag.doubleTapZoom |
                      InteractiveFlag.pinchZoom,
                ),
              ),
              children: [
                // OpenStreetMap's own map, recoloured to suit the app: muted in
                // light mode so the radar colours stand out, and turned into a
                // dark map in dark mode.
                ColorFiltered(
                  colorFilter: ColorFilter.matrix(dark ? _darkMap : _mutedMap),
                  child: TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.petenid.weather_dash',
                  ),
                ),
                // Every radar picture is its own layer; only the current one
                // is visible. Keeping them all loaded makes the animation smooth.
                if (host != null)
                  for (var i = 0; i < _frames.length; i++)
                    Opacity(
                      opacity: i == _index ? 0.8 : 0,
                      child: TileLayer(
                        key: ValueKey(_frames[i].path),
                        // 256 px tiles, colour scheme 2, smoothed, snow shown separately.
                        urlTemplate: '$host${_frames[i].path}/256/{z}/{x}/{y}/2/1_1.png',
                        maxNativeZoom: 7, // RainViewer's most detailed level.
                        userAgentPackageName: 'com.petenid.weather_dash',
                      ),
                    ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: centre,
                      width: 18,
                      height: 18,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.primary,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => widget.onOpenLink('https://www.openstreetmap.org/copyright'),
                    ),
                    TextSourceAttribution(
                      'RainViewer',
                      onTap: () => widget.onOpenLink('https://www.rainviewer.com/'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text("Couldn't load the radar pictures. $_error"),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ],
            ),
          ),
        const SizedBox(height: 6),
        Text(
          'Coloured areas show rain and snow; deeper colours mean heavier precipitation. '
          'Drag to move the map, double-click to zoom in.',
          style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
        ),
      ],
    );
  }
}
