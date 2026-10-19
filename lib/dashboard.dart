import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'weather.dart';

/// Everything below the horizon: the hourly chart, the 7-day forecast,
/// the details panel and the credits.
class GroundSections extends StatelessWidget {
  const GroundSections({
    super.key,
    required this.report,
    required this.fahrenheit,
    required this.onOpenLink,
  });

  final WeatherReport report;
  final bool fahrenheit;
  final void Function(String url) onOpenLink;

  @override
  Widget build(BuildContext context) {
    final hourly = HourlySection(hours: report.hourly, tempUnit: report.tempUnit);
    final daily = DailySection(
      days: report.daily,
      currentTemp: report.current.temperature,
      fahrenheit: fahrenheit,
    );
    final details = DetailsPanel(report: report);

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

/// A line chart of the temperature over the next 24 hours.
class HourlySection extends StatelessWidget {
  const HourlySection({super.key, required this.hours, required this.tempUnit});

  final List<HourlyPoint> hours;
  final String tempUnit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 14);

    if (hours.isEmpty) return const SizedBox.shrink();

    // Give the line some breathing room above and below.
    final temps = hours.map((h) => h.temperature);
    final minY = (temps.reduce(math.min) - 2).floorToDouble();
    final maxY = (temps.reduce(math.max) + 2).ceilToDouble();

    // One point per hour: x is the hour number (0–23), y is the temperature.
    final spots = [
      for (var i = 0; i < hours.length; i++)
        FlSpot(i.toDouble(), hours[i].temperature),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Next 24 hours', style: theme.textTheme.titleMedium),
        const SizedBox(height: 20),
        SizedBox(
          height: 220,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: colors.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: (maxY - minY) <= 12 ? 2 : 5,
                    getTitlesWidget: (value, meta) {
                      if (value == meta.min || value == meta.max) {
                        return const SizedBox.shrink();
                      }
                      return Text(degrees(value), style: muted);
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      // Label every third hour so the times don't crowd.
                      if (i % 3 != 0 || i >= hours.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          i == 0 ? 'Now' : hoursMinutes(hours[i].time),
                          style: muted,
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colors.onSurface,
                  getTooltipItems: (touchedSpots) => [
                    for (final spot in touchedSpots)
                      LineTooltipItem(
                        '${hoursMinutes(hours[spot.x.toInt()].time)}\n'
                        '${spot.y.toStringAsFixed(1)}$tempUnit',
                        TextStyle(
                          color: colors.surface,
                          fontFamily: bodyFont,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: colors.primary,
                  barWidth: 2.5,
                  // A dot marks "now", at the start of the line.
                  dotData: FlDotData(
                    show: true,
                    checkToShowDot: (spot, _) => spot.x == 0,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: 5,
                      color: colors.primary,
                      strokeWidth: 2.5,
                      strokeColor: colors.surface,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        colors.primary.withValues(alpha: 0.25),
                        colors.primary.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
  });

  final List<DailyForecast> days;
  final double currentTemp;
  final bool fahrenheit;

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
        const SizedBox(height: 8),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(),
          _DayRow(
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
    required this.day,
    required this.label,
    required this.weekLow,
    required this.weekHigh,
    required this.marker,
    required this.fahrenheit,
  });

  final DailyForecast day;
  final String label;
  final double weekLow;
  final double weekHigh;
  final double? marker;
  final bool fahrenheit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 52,
      child: Row(
        children: [
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
        ],
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
  const DetailsPanel({super.key, required this.report});

  final WeatherReport report;

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
