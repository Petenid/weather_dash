import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'sky_animation.dart';
import 'theme.dart';
import 'weather.dart';

const _windowChannel = MethodChannel('weather_dash/window');

/// Asks the Windows side to shrink to a small always-on-top window (true)
/// or go back to normal (false). Does nothing where that isn't available.
Future<void> setMiniWindow(bool on) async {
  try {
    await _windowChannel.invokeMethod<void>('setMiniMode', on);
  } on MissingPluginException {
    // Not running on Windows: the layout still changes, the window doesn't.
  } on PlatformException {
    // Same as above.
  }
}

/// The compact view for mini mode: the sky, the place, and the numbers that
/// matter most.
class MiniView extends StatelessWidget {
  const MiniView({
    super.key,
    required this.placeLabel,
    required this.report,
    required this.onExit,
  });

  final String placeLabel;
  final WeatherReport? report;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final report = this.report;
    final colors = report == null
        ? loadingSky
        : skyColors(report.current.weatherCode, isDay: report.current.isDay);
    final soft = Colors.white.withValues(alpha: 0.88);

    return Scaffold(
      body: GestureDetector(
        onDoubleTap: onExit,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (report != null)
                Positioned.fill(
                  child: SkyAnimation(
                    weatherCode: report.current.weatherCode,
                    isDay: report.current.isDay,
                  ),
                ),
              Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(color: Colors.white),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 8, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                placeLabel,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.open_in_full, size: 20),
                              color: Colors.white,
                              tooltip: 'Back to the full window (Ctrl+M)',
                              onPressed: onExit,
                            ),
                          ],
                        ),
                        const Spacer(),
                        if (report == null)
                          const Center(child: CircularProgressIndicator(color: Colors.white))
                        else ...[
                          Text(
                            degrees(report.current.temperature),
                            style: numberStyle(88, weight: FontWeight.w300, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                weatherIcon(report.current.weatherCode, isDay: report.current.isDay),
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  describeWeather(report.current.weatherCode),
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          if (report.today != null)
                            Text(
                              'High ${degrees(report.today!.high)}    Low ${degrees(report.today!.low)}',
                              style: TextStyle(fontSize: 15, color: soft),
                            ),
                        ],
                      ],
                    ),
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
