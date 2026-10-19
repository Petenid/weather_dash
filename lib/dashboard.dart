import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'air_quality.dart';
import 'day_details.dart';
import 'hourly_chart.dart';
import 'moon.dart';
import 'theme.dart';
import 'weather.dart';

/// Everything below the horizon: the hourly chart, the 7-day forecast,
/// the details panel and the credits.
class GroundSections extends StatelessWidget {
  const GroundSections({
    super.key,
    required this.report,
    required this.fahrenheit,
    required this.comparison,
    required this.insights,
    required this.radar,
    required this.air,
    required this.airError,
    required this.onOpenLink,
  });

  final WeatherReport report;
  final bool fahrenheit;
  final Widget comparison; // The forecast-models section.
  final Widget insights; // "At a glance".
  final Widget radar;
  final AirQuality? air;
  final String? airError;
  final void Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final hourly = HourlyPanel(
      title: 'Next 24 hours',
      hours: report.next24Hours,
      report: report,
      startsNow: true,
    );
    final daily = DailySection(
      days: report.daily,
      currentTemp: report.current.temperature,
      fahrenheit: fahrenheit,
      onOpenDay: (i) => showDayDetails(context, report, i),
    );
    final details = DetailsPanel(report: report, air: air, airError: airError);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Wide windows get two columns; narrow ones stack everything.
              final wide = constraints.maxWidth >= 860;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  insights,
                  const SizedBox(height: 36),
                  if (wide)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [hourly, const SizedBox(height: 40), daily],
                          ),
                        ),
                        const SizedBox(width: 36),
                        SizedBox(width: 300, child: details),
                      ],
                    )
                  else ...[
                    hourly,
                    const SizedBox(height: 40),
                    daily,
                    const SizedBox(height: 40),
                    details,
                  ],
                  const SizedBox(height: 48),
                  radar,
                  const SizedBox(height: 48),
                  comparison,
                  const SizedBox(height: 40),
                  const Divider(),
                  const SizedBox(height: 12),
                  _Credits(onOpenLink: onOpenLink),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The week ahead. Each day's bar spans its low to its high on a scale shared
/// by the whole week, coloured by temperature.
class DailySection extends StatelessWidget {
  const DailySection({
    super.key,
    required this.days,
    required this.currentTemp,
    required this.fahrenheit,
    required this.onOpenDay,
  });

  final List<DailyForecast> days;
  final double currentTemp;
  final bool fahrenheit;
  final void Function(int index) onOpenDay;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (days.isEmpty) return const SizedBox.shrink();

    final weekLow = days.map((d) => d.low).reduce(math.min);
    final weekHigh = days.map((d) => d.high).reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('7-day forecast', style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          'Click a day for hour-by-hour details.',
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(),
          _DayRow(
            onTap: () => onOpenDay(i),
            day: days[i],
            label: i == 0 ? 'Today' : _weekdayName(days[i].date),
            weekLow: weekLow,
            weekHigh: weekHigh,
            // Today's bar also shows where the temperature is right now.
            marker: i == 0 ? currentTemp : null,
            fahrenheit: fahrenheit,
          ),
        ],
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.onTap,
    required this.day,
    required this.label,
    required this.weekLow,
    required this.weekHigh,
    required this.marker,
    required this.fahrenheit,
  });

  final VoidCallback onTap;
  final DailyForecast day;
  final String label;
  final double weekLow;
  final double weekHigh;
  final double? marker;
  final bool fahrenheit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 6),
            SizedBox(
              width: 64,
              child: Text(
                label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(
              width: 40,
              child: Tooltip(
                message: describeWeather(day.weatherCode),
                child: Icon(weatherIcon(day.weatherCode, isDay: true), size: 24),
              ),
            ),
            SizedBox(
              width: 56,
              // Only mention rain or snow when it's reasonably likely.
              child: day.precipitationChance >= 10
                  ? Row(
                      children: [
                        Icon(Icons.water_drop, size: 13, color: colors.primary),
                        const SizedBox(width: 2),
                        Text(
                          '${day.precipitationChance}%',
                          style: TextStyle(fontSize: 14, color: colors.primary),
                        ),
                      ],
                    )
                  : null,
            ),
            SizedBox(
              width: 44,
              child: Text(
                degrees(day.low),
                textAlign: TextAlign.right,
                style: numberStyle(21, color: colors.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _RangeBar(
                low: day.low,
                high: day.high,
                weekLow: weekLow,
                weekHigh: weekHigh,
                marker: marker,
                fahrenheit: fahrenheit,
              ),
            ),
            const SizedBox(width: 14),
            SizedBox(
              width: 44,
              child: Text(degrees(day.high), style: numberStyle(21, weight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _RangeBar extends StatelessWidget {
  const _RangeBar({
    required this.low,
    required this.high,
    required this.weekLow,
    required this.weekHigh,
    required this.marker,
    required this.fahrenheit,
  });

  final double low;
  final double high;
  final double weekLow;
  final double weekHigh;
  final double? marker;
  final bool fahrenheit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final span = math.max(weekHigh - weekLow, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final start = (low - weekLow) / span * width;
        final length = math.max((high - low) / span * width, 6.0);
        final marker = this.marker;

        return SizedBox(
          height: 14,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // The track: the whole week's range.
              Container(
                width: width,
                height: 6,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // This day's range.
              Positioned(
                left: start,
                width: length,
                child: Container(
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(3),
                    gradient: LinearGradient(
                      colors: [
                        temperatureColor(toCelsius(low, fahrenheit: fahrenheit)),
                        temperatureColor(toCelsius(high, fahrenheit: fahrenheit)),
                      ],
                    ),
                  ),
                ),
              ),
              // Where the temperature is right now (today only).
              if (marker != null)
                Positioned(
                  left: ((marker - weekLow) / span * width - 6).clamp(0.0, math.max(width - 12, 0.0)),
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors.surface,
                      border: Border.all(color: colors.onSurface, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The smaller numbers: wind, humidity, UV and daylight.
class DetailsPanel extends StatelessWidget {
  const DetailsPanel({
    super.key,
    required this.report,
    required this.air,
    required this.airError,
  });

  final WeatherReport report;
  final AirQuality? air; // Null while loading or if it failed.
  final String? airError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = report.current;
    final today = report.today;
    final sunrise = today?.sunrise;
    final sunset = today?.sunset;
    final uv = now.uvIndex;
    final uvMax = today?.uvMax;
    final moon = MoonPhase.at(DateTime.now());
    final aqi = air?.usAqi;
    final pm25 = air?.pm25;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Details', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DetailRow(
            label: 'Wind',
            note: 'From the ${_compassName(now.windDirection)}',
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The arrow points the way the wind is blowing.
                Transform.rotate(
                  angle: (now.windDirection + 180) * math.pi / 180,
                  child: Icon(Icons.navigation, size: 16, color: colors.primary),
                ),
                const SizedBox(width: 6),
                Text('${now.windSpeed.round()} ${report.windUnit}', style: numberStyle(22)),
              ],
            ),
          ),
          _DetailRow(
            label: 'Humidity',
            value: Text('${now.humidity}%', style: numberStyle(22)),
          ),
          _DetailRow(
            label: 'Air quality',
            note: aqi != null
                ? '${aqiLevel(aqi)}${pm25 == null ? '' : ', fine particles ${pm25.round()} µg/m³'}'
                : airError != null
                    ? 'Unavailable right now'
                    : 'Loading…',
            value: aqi == null
                ? Text('–', style: numberStyle(22))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: aqiColor(aqi)),
                      ),
                      const SizedBox(width: 8),
                      Tooltip(
                        message: 'US Air Quality Index, 0 to 500. Lower is better.',
                        child: Text('$aqi', style: numberStyle(22)),
                      ),
                    ],
                  ),
          ),
          _DetailRow(
            label: 'UV index',
            note: uv == null ? null : uvLevel(uv),
            value: Text(uv == null ? '–' : '${uv.round()}', style: numberStyle(22)),
          ),
          if (uvMax != null)
            _DetailRow(
              label: 'UV peak today',
              note: uvLevel(uvMax),
              value: Text('${uvMax.round()}', style: numberStyle(22)),
            ),
          _DetailRow(
            label: 'Moon',
            note: '${moon.name}, ${(moon.illumination * 100).round()}% lit',
            value: MoonPicture(phase: moon, darkColor: colors.outlineVariant),
          ),
          if (sunrise != null)
            _DetailRow(
              label: 'Sunrise',
              value: Text(hoursMinutes(sunrise), style: numberStyle(22)),
            ),
          if (sunset != null)
            _DetailRow(
              label: 'Sunset',
              value: Text(hoursMinutes(sunset), style: numberStyle(22)),
            ),
          if (sunrise != null && sunset != null)
            _DetailRow(
              label: 'Daylight',
              value: Text(_duration(sunset.difference(sunrise)), style: numberStyle(22)),
              last: true,
            ),
          const SizedBox(height: 14),
          Text(
            'Updated ${hoursMinutes(now.time)}, local time. Refreshes every 15 minutes.',
            style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.note,
    this.last = false,
  });

  final String label;
  final String? note;
  final Widget value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final note = this.note;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 15)),
                if (note != null)
                  Text(
                    note,
                    style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          value,
        ],
      ),
    );
  }
}

class _Credits extends StatelessWidget {
  const _Credits({required this.onOpenLink});

  final void Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final plain = TextStyle(fontSize: 13, color: colors.onSurfaceVariant);

    Widget link(String label, String url) {
      return InkWell(
        onTap: () => onOpenLink(url),
        borderRadius: BorderRadius.circular(4),
        child: Text(
          label,
          style: plain.copyWith(
            color: colors.primary,
            decoration: TextDecoration.underline,
            decorationColor: colors.primary,
          ),
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text('Weather data by ', style: plain),
        link('Open-Meteo.com', 'https://open-meteo.com/'),
        Text('. Place search by ', style: plain),
        link('GeoNames', 'https://www.geonames.org/'),
        Text('. Air quality from the ', style: plain),
        link('Copernicus Atmosphere Monitoring Service', 'https://atmosphere.copernicus.eu/'),
        Text('. Past weather from ', style: plain),
        link('ERA5, Copernicus Climate Change Service', 'https://climate.copernicus.eu/'),
        Text('. Alerts from ', style: plain),
        link('Environment and Climate Change Canada', 'https://weather.gc.ca/'),
        Text('. Aurora forecast from ', style: plain),
        link('NOAA Space Weather Prediction Center', 'https://www.swpc.noaa.gov/'),
        Text('. Radar from ', style: plain),
        link('RainViewer', 'https://www.rainviewer.com/'),
        Text(', maps from ', style: plain),
        link('OpenStreetMap contributors', 'https://www.openstreetmap.org/copyright'),
        Text('.', style: plain),
      ],
    );
  }
}

String _weekdayName(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[date.weekday - 1];
}

String _compassName(int degrees) {
  const names = {
    'N': 'north',
    'NE': 'northeast',
    'E': 'east',
    'SE': 'southeast',
    'S': 'south',
    'SW': 'southwest',
    'W': 'west',
    'NW': 'northwest',
  };
  return names[compassDirection(degrees)]!;
}

/// "10 h 47 min".
String _duration(Duration d) => '${d.inHours} h ${d.inMinutes % 60} min';
