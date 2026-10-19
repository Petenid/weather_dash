import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'air_quality.dart';
import 'day_details.dart';
import 'hourly_chart.dart';
import 'feels.dart';
import 'moon.dart';
import 'solar.dart';
import 'strings.dart';
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
    required this.latitude,
    required this.longitude,
    this.refreshMinutes = 15,
  });

  final double latitude;
  final double longitude;
  final int refreshMinutes;

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
      title: t.next24Hours,
      hours: report.next24Hours,
      report: report,
      startsNow: true,
    );
    final daily = DailySection(
      days: report.daily,
      currentTemp: report.current.temperature,
      fahrenheit: fahrenheit,
      onOpenDay: (i) => showDayDetails(context, report, i, latitude: latitude, longitude: longitude),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DetailsPanel(report: report, air: air, airError: airError, refreshMinutes: refreshMinutes),
        const SizedBox(height: 20),
        PhotoTimesPanel(report: report, latitude: latitude, longitude: longitude),
      ],
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Padding(
          padding: EdgeInsets.fromLTRB(sideGap(context), 32, sideGap(context), 20),
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
        Text(t.sevenDay, style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          t.clickADay,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < days.length; i++) ...[
          if (i > 0) const Divider(),
          _DayRow(
            onTap: () => onOpenDay(i),
            day: days[i],
            label: i == 0 ? t.today : t.weekdayShort(days[i].date),
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

    // On a phone-width screen, the rain chance moves under the day's name
    // and the arrow is left out, so the temperature bar keeps its room.
    final compact = MediaQuery.sizeOf(context).width < 520;
    final rain = day.precipitationChance >= 10
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.water_drop, size: 13, color: colors.primary),
              const SizedBox(width: 2),
              // French adds a space before %, so let the number shrink a
              // little rather than overflow if space is tight.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    t.percent(day.precipitationChance),
                    maxLines: 1,
                    style: TextStyle(fontSize: 14, color: colors.primary),
                  ),
                ),
              ),
            ],
          )
        : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            const SizedBox(width: 6),
            SizedBox(
              width: compact ? 72 : 92,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shrinks a long name like "Aujourd'hui" rather than wrapping it.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (compact && rain != null) rain,
                ],
              ),
            ),
            SizedBox(
              width: 40,
              child: Tooltip(
                message: describeWeather(day.weatherCode),
                child: Icon(weatherIcon(day.weatherCode, isDay: true), size: 24),
              ),
            ),
            // Only mention rain or snow when it's reasonably likely.
            if (!compact) SizedBox(width: 72, child: rain),
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
            if (!compact) Icon(Icons.chevron_right, size: 20, color: colors.onSurfaceVariant),
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
    this.refreshMinutes = 15,
  });

  final WeatherReport report;
  final AirQuality? air; // Null while loading or if it failed.
  final String? airError;
  final int refreshMinutes;

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

    // Wind chill and humidex are worked out in °C and km/h, then shown in
    // the units on screen.
    final fahrenheit = report.tempUnit == '°F';
    final tempC = toCelsius(now.temperature, fahrenheit: fahrenheit);
    double shown(double c) => fahrenheit ? c * 9 / 5 + 32 : c;
    final chill = windChillC(tempC, toKmh(now.windSpeed, report.windUnit));
    final humidex = humidexC(tempC, now.humidity);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.details, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _DetailRow(
            label: t.wind,
            note: t.fromDirection(compassName(now.windDirection)),
            value: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The arrow points the way the wind is blowing.
                Transform.rotate(
                  angle: (now.windDirection + 180) * math.pi / 180,
                  child: Icon(Icons.navigation, size: 16, color: colors.primary),
                ),
                const SizedBox(width: 6),
                Text('${now.windSpeed.round()} ${report.windLabel}', style: numberStyle(22)),
              ],
            ),
          ),
          _DetailRow(
            label: t.humidity,
            value: Text(t.percent(now.humidity), style: numberStyle(22)),
          ),
          if (chill != null)
            _DetailRow(
              label: t.windChill,
              note: t.windChillRisk(chill),
              value: Text(degrees(shown(chill)), style: numberStyle(22)),
            ),
          if (humidex != null)
            _DetailRow(
              label: t.humidex,
              note: t.humidexLevel(humidex),
              // Humidex is always given on the Celsius scale, even in °F.
              value: Text('${humidex.round()}', style: numberStyle(22)),
            ),
          _DetailRow(
            label: t.airQuality,
            note: aqi != null
                ? '${aqiLevel(aqi)}${pm25 == null ? '' : ', ${t.fineParticles(pm25.round())}'}'
                : airError != null
                    ? t.unavailable
                    : t.loading,
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
                        message: t.aqiTip,
                        child: Text('$aqi', style: numberStyle(22)),
                      ),
                    ],
                  ),
          ),
          _DetailRow(
            label: t.uvIndex,
            note: uv == null ? null : uvLevel(uv),
            value: Text(uv == null ? '–' : '${uv.round()}', style: numberStyle(22)),
          ),
          if (uvMax != null)
            _DetailRow(
              label: t.uvPeakToday,
              note: uvLevel(uvMax),
              value: Text('${uvMax.round()}', style: numberStyle(22)),
            ),
          _DetailRow(
            label: t.moon,
            note: t.moonLit(moon.name, (moon.illumination * 100).round()),
            value: MoonPicture(phase: moon, darkColor: colors.outlineVariant),
          ),
          if (sunrise != null)
            _DetailRow(
              label: t.sunrise,
              value: Text(hoursMinutes(sunrise), style: numberStyle(22)),
            ),
          if (sunset != null)
            _DetailRow(
              label: t.sunset,
              value: Text(hoursMinutes(sunset), style: numberStyle(22)),
            ),
          if (sunrise != null && sunset != null)
            _DetailRow(
              label: t.daylight,
              value: Text(t.duration(sunset.difference(sunrise)), style: numberStyle(22)),
              last: true,
            ),
          const SizedBox(height: 14),
          Text(
            t.updated(hoursMinutes(now.time), refreshMinutes),
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
        Text(t.creditsWeather, style: plain),
        link('Open-Meteo.com', 'https://open-meteo.com/'),
        Text(t.creditsPlaces, style: plain),
        link('GeoNames', 'https://www.geonames.org/'),
        Text(t.creditsAir, style: plain),
        link(t.creditsAirName, 'https://atmosphere.copernicus.eu/'),
        Text(t.creditsPast, style: plain),
        link(t.creditsPastName, 'https://climate.copernicus.eu/'),
        Text(t.creditsAlerts, style: plain),
        link(t.creditsAlertsName, t.fr ? 'https://meteo.gc.ca/' : 'https://weather.gc.ca/'),
        Text(t.creditsAurora, style: plain),
        link(t.creditsAuroraName, 'https://www.swpc.noaa.gov/'),
        Text(t.creditsRadar, style: plain),
        link('RainViewer', 'https://www.rainviewer.com/'),
        Text(t.creditsMaps, style: plain),
        link(t.mapContributors, 'https://www.openstreetmap.org/copyright'),
        Text('.', style: plain),
      ],
    );
  }
}

/// Golden and blue hour for today: the soft light photographers look for.
class PhotoTimesPanel extends StatelessWidget {
  const PhotoTimesPanel({
    super.key,
    required this.report,
    required this.latitude,
    required this.longitude,
  });

  final WeatherReport report;
  final double latitude;
  final double longitude;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final day = report.today?.date ?? report.current.time;
    final times = photoTimes(latitude, longitude, day, report.utcOffset);
    if (times.isEmpty) return const SizedBox.shrink();

    String range(TimeSpan s) => t.timeRange(hoursMinutes(s.start), hoursMinutes(s.end));
    final rows = <(String, TimeSpan?, Color)>[
      (t.blueHourMorning, times.morningBlue, const Color(0xFF4A6FD0)),
      (t.goldenHourMorning, times.morningGolden, const Color(0xFFE9A23B)),
      (t.goldenHourEvening, times.eveningGolden, const Color(0xFFE9A23B)),
      (t.blueHourEvening, times.eveningBlue, const Color(0xFF4A6FD0)),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(t.lightForPhotos, style: theme.textTheme.titleMedium)),
              Tooltip(
                message: t.photoTip,
                child: Icon(Icons.info_outline, size: 18, color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final (label, span, swatch) in rows)
            if (span != null)
              // The name on one line and the times under it, so neither has
              // to squeeze into half the panel's width.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: swatch),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label, style: const TextStyle(fontSize: 15)),
                          const SizedBox(height: 2),
                          Text(range(span), style: numberStyle(19)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
