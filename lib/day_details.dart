import 'package:flutter/material.dart';

import 'hourly_chart.dart';
import 'solar.dart';
import 'theme.dart';
import 'weather.dart';
import 'strings.dart';

/// Opens the details for one day of the forecast.
void showDayDetails(
  BuildContext context,
  WeatherReport report,
  int dayIndex, {
  required double latitude,
  required double longitude,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => DayDetailsDialog(
      report: report,
      initialIndex: dayIndex,
      latitude: latitude,
      longitude: longitude,
    ),
  );
}

/// Everything about one day, with arrows to step through the week.
class DayDetailsDialog extends StatefulWidget {
  const DayDetailsDialog({
    super.key,
    required this.report,
    required this.initialIndex,
    required this.latitude,
    required this.longitude,
  });

  final WeatherReport report;
  final int initialIndex;
  final double latitude;
  final double longitude;

  @override
  State<DayDetailsDialog> createState() => _DayDetailsDialogState();
}

class _DayDetailsDialogState extends State<DayDetailsDialog> {
  late int _index = widget.initialIndex;

  /// The golden-hour and blue-hour times for a day, with their names.
  List<(String, TimeSpan)> _photoSpans(DateTime day) {
    final p = photoTimes(widget.latitude, widget.longitude, day, widget.report.utcOffset);
    return [
      if (p.morningGolden case final s?) (t.goldenHourMorning, s),
      if (p.eveningGolden case final s?) (t.goldenHourEvening, s),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final report = widget.report;
    final days = report.daily;
    final day = days[_index];
    final muted = TextStyle(fontSize: 15, color: colors.onSurfaceVariant);
    final uv = day.uvMax;
    final windFrom = day.windDirection;
    final amount = t.decimal(day.precipitationTotal, report.precipUnit == 'in' ? 2 : 1);

    return Dialog(
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _index == 0 ? t.todayDate(day.date) : t.fullDate(day.date),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: t.previousDay,
                    onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: t.nextDay,
                    onPressed: _index < days.length - 1 ? () => setState(() => _index++) : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: t.close,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 24,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(weatherIcon(day.weatherCode, isDay: true), size: 30),
                      const SizedBox(width: 10),
                      Text(
                        describeWeather(day.weatherCode),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text('${t.highWord} ', style: muted),
                      Text(degrees(day.high), style: numberStyle(30, weight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text('${t.lowWord} ', style: muted),
                      Text(degrees(day.low), style: numberStyle(30, color: colors.onSurfaceVariant)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Wrap(
                spacing: 36,
                runSpacing: 16,
                children: [
                  _Fact(label: t.chanceOfPrecip, value: t.percent(day.precipitationChance)),
                  _Fact(label: t.expectedTotal, value: '$amount ${report.precipUnit}'),
                  _Fact(
                    label: windFrom == null
                        ? t.strongestWind
                        : t.strongestWindFrom(compassName(windFrom)),
                    value: '${day.windMax.round()} ${report.windLabel}',
                  ),
                  _Fact(label: t.gustsUpTo, value: '${day.gustMax.round()} ${report.windLabel}'),
                  if (uv != null) _Fact(label: t.uvPeak(uvLevel(uv)), value: '${uv.round()}'),
                  if (day.sunrise != null) _Fact(label: t.sunrise, value: hoursMinutes(day.sunrise!)),
                  if (day.sunset != null) _Fact(label: t.sunset, value: hoursMinutes(day.sunset!)),
                  for (final (label, span) in _photoSpans(day.date))
                    _Fact(label: label, value: t.timeRange(hoursMinutes(span.start), hoursMinutes(span.end))),
                ],
              ),
              const SizedBox(height: 32),
              HourlyPanel(
                // A new key per day resets the chart cleanly when you switch days.
                key: ValueKey(_index),
                title: t.hourByHour,
                hours: report.hoursOn(day.date),
                report: report,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: muted)),
        const SizedBox(height: 2),
        Text(value, style: numberStyle(24)),
      ],
    );
  }
}
