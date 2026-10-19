import 'package:flutter/material.dart';

import 'hourly_chart.dart';
import 'theme.dart';
import 'weather.dart';

/// Opens the details for one day of the forecast.
void showDayDetails(BuildContext context, WeatherReport report, int dayIndex) {
  showDialog<void>(
    context: context,
    builder: (_) => DayDetailsDialog(report: report, initialIndex: dayIndex),
  );
}

/// Everything about one day, with arrows to step through the week.
class DayDetailsDialog extends StatefulWidget {
  const DayDetailsDialog({super.key, required this.report, required this.initialIndex});

  final WeatherReport report;
  final int initialIndex;

  @override
  State<DayDetailsDialog> createState() => _DayDetailsDialogState();
}

class _DayDetailsDialogState extends State<DayDetailsDialog> {
  late int _index = widget.initialIndex;

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
    final amount = report.precipUnit == 'in'
        ? day.precipitationTotal.toStringAsFixed(2)
        : day.precipitationTotal.toStringAsFixed(1);

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
                      _index == 0 ? 'Today, ${_dateName(day.date)}' : _fullDate(day.date),
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous day',
                    onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next day',
                    onPressed: _index < days.length - 1 ? () => setState(() => _index++) : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Close',
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
                      Text('High ', style: muted),
                      Text(degrees(day.high), style: numberStyle(30, weight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Text('Low ', style: muted),
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
                  _Fact(label: 'Chance of rain or snow', value: '${day.precipitationChance}%'),
                  _Fact(label: 'Expected total', value: '$amount ${report.precipUnit}'),
                  _Fact(
                    label: windFrom == null
                        ? 'Strongest wind'
                        : 'Strongest wind, from the ${compassDirection(windFrom)}',
                    value: '${day.windMax.round()} ${report.windUnit}',
                  ),
                  _Fact(label: 'Gusts up to', value: '${day.gustMax.round()} ${report.windUnit}'),
                  if (uv != null) _Fact(label: 'UV peak, ${uvLevel(uv).toLowerCase()}', value: '${uv.round()}'),
                  if (day.sunrise != null) _Fact(label: 'Sunrise', value: hoursMinutes(day.sunrise!)),
                  if (day.sunset != null) _Fact(label: 'Sunset', value: hoursMinutes(day.sunset!)),
                ],
              ),
              const SizedBox(height: 32),
              HourlyPanel(
                // A new key per day resets the chart cleanly when you switch days.
                key: ValueKey(_index),
                title: 'Hour by hour',
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

const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _dateName(DateTime d) => '${_months[d.month - 1]} ${d.day}';
String _fullDate(DateTime d) => '${_weekdays[d.weekday - 1]}, ${_dateName(d)}';
