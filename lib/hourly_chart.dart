import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'theme.dart';
import 'weather.dart';
import 'strings.dart';

/// What the hourly chart is showing.
enum ChartView { temperature, precipitation, wind }

/// A titled hour-by-hour chart with a switch for temperature, chance of
/// rain or snow, and wind. Used for "Next 24 hours" and in the day details.
class HourlyPanel extends StatefulWidget {
  const HourlyPanel({
    super.key,
    required this.title,
    required this.hours,
    required this.report,
    this.startsNow = false,
  });

  final String title;
  final List<HourlyPoint> hours;
  final WeatherReport report; // For the units.
  final bool startsNow; // Label the first hour "Now".

  @override
  State<HourlyPanel> createState() => _HourlyPanelState();
}

class _HourlyPanelState extends State<HourlyPanel> {
  ChartView _view = ChartView.temperature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hours = widget.hours;
    if (hours.isEmpty) return const SizedBox.shrink();

    final compact = MediaQuery.sizeOf(context).width < 520;

    String label(int i) =>
        i == 0 && widget.startsNow ? t.now : hoursMinutes(hours[i].time);

    final chart = switch (_view) {
      ChartView.temperature =>
        _TemperatureChart(hours: hours, unit: widget.report.tempUnit, label: label),
      ChartView.precipitation =>
        _PrecipitationChart(hours: hours, unit: widget.report.precipUnit, label: label),
      ChartView.wind =>
        _WindChart(hours: hours, unit: widget.report.windLabel, label: label),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 10,
          children: [
            Text(widget.title, style: theme.textTheme.titleMedium),
            SegmentedButton<ChartView>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              // On a narrow screen the buttons show icons only; hovering or
              // long-pressing shows the name.
              segments: [
                for (final (view, icon, name) in [
                  (ChartView.temperature, Icons.thermostat, t.temperature),
                  (ChartView.precipitation, Icons.water_drop_outlined, t.precipitation),
                  (ChartView.wind, Icons.air, t.wind),
                ])
                  ButtonSegment(
                    value: view,
                    icon: compact ? Icon(icon) : null,
                    label: compact ? null : Text(name),
                    tooltip: compact ? name : null,
                  ),
              ],
              selected: {_view},
              onSelectionChanged: (choice) => setState(() => _view = choice.first),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(height: 230, child: chart),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Pieces shared by all three charts.

TextStyle _axisStyle(BuildContext context) =>
    TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14);

/// Times along the bottom, every third hour so they don't crowd.
AxisTitles _timeAxis(BuildContext context, int count, String Function(int) label) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 30,
      interval: 1,
      getTitlesWidget: (value, meta) {
        final i = value.toInt();
        if (i % 3 != 0 || i >= count || value != i.toDouble()) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(label(i), style: _axisStyle(context)),
        );
      },
    ),
  );
}

/// Values up the left side, skipping the very top and bottom.
AxisTitles _valueAxis(BuildContext context, double interval, String Function(double) format) {
  return AxisTitles(
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: 44,
      interval: interval,
      getTitlesWidget: (value, meta) {
        if (value == meta.min || value == meta.max) return const SizedBox.shrink();
        return Text(format(value), style: _axisStyle(context));
      },
    ),
  );
}

const _noTitles = AxisTitles(sideTitles: SideTitles(showTitles: false));

FlGridData _grid(BuildContext context, {double? interval}) {
  final line = Theme.of(context).colorScheme.outlineVariant;
  return FlGridData(
    drawVerticalLine: false,
    horizontalInterval: interval,
    getDrawingHorizontalLine: (_) => FlLine(color: line, strokeWidth: 1),
  );
}

TextStyle _tooltipStyle(BuildContext context, {bool bold = false}) => TextStyle(
      color: Theme.of(context).colorScheme.surface,
      fontFamily: bodyFont,
      fontSize: 13,
      fontWeight: bold ? FontWeight.w600 : FontWeight.w500,
    );

// ---------------------------------------------------------------------------

class _TemperatureChart extends StatelessWidget {
  const _TemperatureChart({required this.hours, required this.unit, required this.label});

  final List<HourlyPoint> hours;
  final String unit;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final temps = hours.map((h) => h.temperature);
    final minY = (temps.reduce(math.min) - 2).floorToDouble();
    final maxY = (temps.reduce(math.max) + 2).ceilToDouble();

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: _grid(context),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: _noTitles,
          rightTitles: _noTitles,
          leftTitles: _valueAxis(context, (maxY - minY) <= 12 ? 2 : 5, degrees),
          bottomTitles: _timeAxis(context, hours.length, label),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.onSurface,
            fitInsideHorizontally: true,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${hoursMinutes(hours[s.x.toInt()].time)}\n'
                  '${t.decimal(s.y, 1)}$unit',
                  _tooltipStyle(context, bold: true),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < hours.length; i++) FlSpot(i.toDouble(), hours[i].temperature),
            ],
            isCurved: true,
            preventCurveOverShooting: true,
            color: colors.primary,
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
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
    );
  }
}

/// Bars for the chance of rain or snow each hour, 0 to 100%.
class _PrecipitationChart extends StatelessWidget {
  const _PrecipitationChart({required this.hours, required this.unit, required this.label});

  final List<HourlyPoint> hours;
  final String unit;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dry = hours.every((h) => h.precipitationChance < 5);

    return Stack(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final barWidth = math.max((constraints.maxWidth - 44) / hours.length * 0.6, 2.0);
            return BarChart(
              BarChartData(
                minY: 0,
                maxY: 100,
                alignment: BarChartAlignment.spaceAround,
                gridData: _grid(context, interval: 25),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: _noTitles,
                  rightTitles: _noTitles,
                  leftTitles: _valueAxis(context, 25, (v) => t.percent(v)),
                  bottomTitles: _timeAxis(context, hours.length, label),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => colors.onSurface,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final h = hours[group.x];
                      final amount = t.decimal(h.precipitation, unit == 'in' ? 2 : 1);
                      return BarTooltipItem(
                        '${hoursMinutes(h.time)}\n',
                        _tooltipStyle(context, bold: true),
                        children: [
                          TextSpan(
                            text: t.precipTooltip(t.percent(h.precipitationChance), '$amount $unit'),
                            style: _tooltipStyle(context),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < hours.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: hours[i].precipitationChance.toDouble(),
                          color: colors.primary,
                          width: barWidth,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        if (dry)
          Align(
            alignment: const Alignment(0, -0.2),
            child: Text(
              t.noPrecipExpected,
              style: TextStyle(fontSize: 16, color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Wind speed as a solid line and gusts as a dashed one.
class _WindChart extends StatelessWidget {
  const _WindChart({required this.hours, required this.unit, required this.label});

  final List<HourlyPoint> hours;
  final String unit;
  final String Function(int) label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strongest = hours.map((h) => math.max(h.windGusts, h.windSpeed)).reduce(math.max);
    final maxY = math.max((strongest * 1.15 / 5).ceil() * 5.0, 10.0);

    LineChartBarData line(double Function(HourlyPoint) value, {required bool dashed}) {
      return LineChartBarData(
        spots: [for (var i = 0; i < hours.length; i++) FlSpot(i.toDouble(), value(hours[i]))],
        isCurved: true,
        preventCurveOverShooting: true,
        color: dashed ? colors.primary.withValues(alpha: 0.75) : colors.primary,
        barWidth: dashed ? 1.75 : 2.5,
        dashArray: dashed ? [6, 4] : null,
        dotData: const FlDotData(show: false),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Legend: the two lines differ by style, not colour.
        Row(
          children: [
            _LineSample(color: colors.primary, dashed: false),
            const SizedBox(width: 6),
            Text(t.wind),
            const SizedBox(width: 20),
            _LineSample(color: colors.primary.withValues(alpha: 0.75), dashed: true),
            const SizedBox(width: 6),
            Text(t.gusts),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: _grid(context),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: _noTitles,
                rightTitles: _noTitles,
                leftTitles: _valueAxis(context, maxY <= 40 ? 10 : 20, (v) => '${v.round()}'),
                bottomTitles: _timeAxis(context, hours.length, label),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => colors.onSurface,
                  fitInsideHorizontally: true,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        s.barIndex == 0
                            ? '${hoursMinutes(hours[s.x.toInt()].time)}\n'
                                '${t.wind} ${s.y.round()} $unit'
                            : '${t.gusts} ${s.y.round()} $unit',
                        _tooltipStyle(context, bold: s.barIndex == 0),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                line((h) => h.windSpeed, dashed: false),
                line((h) => h.windGusts, dashed: true),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LineSample extends StatelessWidget {
  const _LineSample({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    Widget bit(double width) => Container(width: width, height: 2.5, color: color);
    return dashed
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [bit(6), const SizedBox(width: 3), bit(6), const SizedBox(width: 3), bit(6)],
          )
        : bit(24);
  }
}
