import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'theme.dart';
import 'weather.dart';

/// One colour per model, in a fixed order, so Canada is always blue,
/// the US always orange and Europe always green, whatever else changes.
/// These were checked to stay distinguishable for colour-blind readers.
const _lightColors = [Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A)];
const _darkColors = [Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70)];

Color _colorFor(BuildContext context, ForecastModel model) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final i = comparedModels.indexOf(model);
  return (dark ? _darkColors : _lightColors)[i];
}

/// "What do different weather models predict?" — a chart of the next three
/// days from each model, a sentence on where they agree, and a table of
/// daily highs and lows.
class ModelComparisonSection extends StatelessWidget {
  const ModelComparisonSection({
    super.key,
    required this.comparison,
    required this.error,
    required this.onRetry,
  });

  final ModelComparison? comparison;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final comparison = this.comparison;
    final error = this.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Forecast models compared', style: theme.textTheme.titleMedium),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Text(
            'The forecast above blends several computer weather models. '
            'Here is what three national weather services predict on their own. '
            'Where they agree, the forecast is more certain.',
            style: TextStyle(fontSize: 15, color: colors.onSurfaceVariant, height: 1.4),
          ),
        ),
        const SizedBox(height: 16),
        if (comparison != null)
          _ComparisonBody(comparison: comparison)
        else if (error != null)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text("Couldn't load the model forecasts. $error"),
              TextButton(onPressed: onRetry, child: const Text('Try again')),
            ],
          )
        else
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ),
      ],
    );
  }
}

class _ComparisonBody extends StatelessWidget {
  const _ComparisonBody({required this.comparison});

  final ModelComparison comparison;

  @override
  Widget build(BuildContext context) {
    final summary = _summary(comparison);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary != null) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Text(
              summary,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _Legend(runs: comparison.runs),
        const SizedBox(height: 16),
        _ModelChart(comparison: comparison),
        const SizedBox(height: 24),
        _DailyTable(comparison: comparison),
      ],
    );
  }
}

/// A plain-language sentence about how much the models agree.
String? _summary(ModelComparison c) {
  final spreads = c.highSpreads;
  final known = [
    for (var i = 0; i < spreads.length; i++)
      if (spreads[i] != null) (day: i, spread: spreads[i]!),
  ];
  if (known.isEmpty) return null;

  // "Close" means within about 2 °C (4 °F).
  final close = c.tempUnit == '°F' ? 4.0 : 2.0;
  final widest = known.reduce((a, b) => b.spread > a.spread ? b : a);
  final models = c.runs.length == 3 ? 'All three models' : 'The models';

  if (widest.spread <= close) {
    return '$models agree closely this week: '
        'their daily highs are never more than ${widest.spread.round()}° apart.';
  }

  final todaySpread = spreads.first;
  final today = todaySpread == null
      ? ''
      : todaySpread <= close
          ? 'They agree closely today. '
          : 'Today their highs are ${todaySpread.round()}° apart. ';
  final day = widest.day == 0 ? 'today' : 'on ${_weekdayName(c.days[widest.day])}';
  return '${today}They disagree most $day, when their highs differ by '
      '${widest.spread.round()}°, so treat that forecast with some caution.';
}

class _Legend extends StatelessWidget {
  const _Legend({required this.runs});

  final List<ModelRun> runs;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return Wrap(
      spacing: 24,
      runSpacing: 8,
      children: [
        for (final run in runs)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 18,
                height: 3,
                decoration: BoxDecoration(
                  color: _colorFor(context, run.model),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(run.model.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
              Text(run.model.source, style: TextStyle(fontSize: 14, color: muted)),
            ],
          ),
      ],
    );
  }
}

class _ModelChart extends StatelessWidget {
  const _ModelChart({required this.comparison});

  final ModelComparison comparison;

  static const _chartHeight = 240.0;
  static const _bottomSpace = 30.0;
  static const _labelWidth = 120.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(color: colors.onSurfaceVariant, fontSize: 14);
    final hours = comparison.hours;
    final runs = comparison.runs;

    final all = [for (final r in runs) ...r.hourly.whereType<double>()];
    final minY = (all.reduce(math.min) - 2).floorToDouble();
    final maxY = (all.reduce(math.max) + 2).ceilToDouble();

    final bars = [
      for (final run in runs)
        LineChartBarData(
          spots: [
            for (var i = 0; i < run.hourly.length; i++)
              run.hourly[i] == null ? FlSpot.nullSpot : FlSpot(i.toDouble(), run.hourly[i]!),
          ],
          isCurved: true,
          preventCurveOverShooting: true,
          color: _colorFor(context, run.model),
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
    ];

    final chart = LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          // A faint vertical line at each midnight separates the days.
          verticalInterval: 1,
          checkToShowVerticalLine: (x) {
            final i = x.toInt();
            return i > 0 && i < hours.length && hours[i].hour == 0;
          },
          getDrawingVerticalLine: (_) => FlLine(color: colors.outlineVariant, strokeWidth: 1),
          getDrawingHorizontalLine: (_) => FlLine(color: colors.outlineVariant, strokeWidth: 1),
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
                if (value == meta.min || value == meta.max) return const SizedBox.shrink();
                return Text(degrees(value), style: muted);
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _bottomSpace,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= hours.length) return const SizedBox.shrink();
                // "Now" at the start, then the day's name at each midnight.
                final label = i == 0
                    ? 'Now'
                    : hours[i].hour == 0
                        ? _weekdayName(hours[i])
                        : null;
                if (label == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(label, style: muted),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colors.onSurface,
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => [
              for (var k = 0; k < touched.length; k++)
                _tooltipItem(context, touched[k], showTime: k == 0),
            ],
          ),
        ),
        lineBarsData: bars,
      ),
    );

    return SizedBox(
      height: _chartHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: chart),
          const SizedBox(width: 10),
          SizedBox(
            width: _labelWidth,
            child: _EndLabels(
              runs: runs,
              minY: minY,
              maxY: maxY,
              plotHeight: _chartHeight - _bottomSpace,
            ),
          ),
        ],
      ),
    );
  }

  LineTooltipItem _tooltipItem(BuildContext context, LineBarSpot spot, {required bool showTime}) {
    final colors = Theme.of(context).colorScheme;
    final run = comparison.runs[spot.barIndex];
    final time = comparison.hours[spot.x.toInt()];
    final textStyle = TextStyle(
      color: colors.surface,
      fontFamily: bodyFont,
      fontWeight: FontWeight.w500,
      fontSize: 13,
    );
    return LineTooltipItem(
      showTime ? '${_weekdayName(time)} ${hoursMinutes(time)}\n' : '',
      textStyle.copyWith(fontWeight: FontWeight.w600),
      textAlign: TextAlign.left,
      children: [
        TextSpan(text: '● ', style: textStyle.copyWith(color: _colorFor(context, run.model))),
        TextSpan(
          text: '${run.model.name}  ${spot.y.toStringAsFixed(1)}${comparison.tempUnit}',
          style: textStyle,
        ),
      ],
    );
  }
}

/// Names at the right-hand end of each line, so you don't have to match
/// colours to the legend. Labels are nudged apart if two lines end close
/// together.
class _EndLabels extends StatelessWidget {
  const _EndLabels({
    required this.runs,
    required this.minY,
    required this.maxY,
    required this.plotHeight,
  });

  final List<ModelRun> runs;
  final double minY;
  final double maxY;
  final double plotHeight;

  @override
  Widget build(BuildContext context) {
    const labelHeight = 18.0;

    // Where each line ends, measured from the top of the chart.
    final ends = <({ModelRun run, double y})>[];
    for (final run in runs) {
      final last = run.hourly.lastWhere((v) => v != null, orElse: () => null);
      if (last == null) continue;
      ends.add((run: run, y: (maxY - last) / (maxY - minY) * plotHeight));
    }
    ends.sort((a, b) => a.y.compareTo(b.y));

    // Push labels down so they don't overlap, then keep them inside the chart.
    final tops = <double>[];
    for (final e in ends) {
      var top = e.y - labelHeight / 2;
      if (tops.isNotEmpty) top = math.max(top, tops.last + labelHeight);
      tops.add(top);
    }
    final overflow = tops.isEmpty ? 0.0 : tops.last + labelHeight - plotHeight;
    final shift = overflow > 0 ? overflow : 0.0;

    return Stack(
      children: [
        for (var i = 0; i < ends.length; i++)
          Positioned(
            left: 0,
            right: 0,
            top: math.max(tops[i] - shift, 0.0),
            height: labelHeight,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _colorFor(context, ends[i].run.model),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    ends[i].run.model.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Each model's daily high and low, side by side.
class _DailyTable extends StatelessWidget {
  const _DailyTable({required this.comparison});

  final ModelComparison comparison;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final days = comparison.days;
    final muted = colors.onSurfaceVariant;

    Widget cell(Widget child) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: child,
        );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const FixedColumnWidth(68),
        columnWidths: const {0: FixedColumnWidth(150)},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(
          horizontalInside: BorderSide(color: colors.outlineVariant),
        ),
        children: [
          TableRow(
            children: [
              cell(Text('High and low', style: TextStyle(fontSize: 14, color: muted))),
              for (var d = 0; d < days.length; d++)
                cell(Text(
                  d == 0 ? 'Today' : _weekdayName(days[d]),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                )),
            ],
          ),
          for (final run in comparison.runs)
            TableRow(
              children: [
                cell(Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _colorFor(context, run.model),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(run.model.name, style: const TextStyle(fontSize: 15)),
                  ],
                )),
                for (var d = 0; d < days.length; d++)
                  cell(Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        run.highs[d] == null ? '–' : degrees(run.highs[d]!),
                        style: numberStyle(19, weight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        run.lows[d] == null ? '' : degrees(run.lows[d]!),
                        style: numberStyle(16, color: muted),
                      ),
                    ],
                  )),
              ],
            ),
        ],
      ),
    );
  }
}

String _weekdayName(DateTime date) {
  const names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return names[date.weekday - 1];
}
