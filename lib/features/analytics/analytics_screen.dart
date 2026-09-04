import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../core/entry.dart';
import '../../data/providers.dart';

final _money =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _touchedSlice = -1;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(ledgerProvider).valueOrNull ?? const <Entry>[];
    final month = ref.watch(selectedMonthProvider);
    final summary = ref.watch(monthSummaryProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM yyyy').format(month).toUpperCase(),
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 2.6,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.45),
                  ),
                ),
                const SizedBox(height: 2),
                Text('Insights',
                    style: Theme.of(context).textTheme.headlineMedium),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 380.ms).slideY(begin: -0.2),

        _FlowCard(entries: entries, month: month)
            .animate()
            .fadeIn(delay: 80.ms, duration: 450.ms)
            .slideY(begin: 0.1, curve: Curves.easeOutCubic),

        const SizedBox(height: 16),

        _CategoryCard(
          entries: entries,
          touched: _touchedSlice,
          onTouch: (i) => setState(() => _touchedSlice = i),
          total: summary.spent,
        )
            .animate()
            .fadeIn(delay: 160.ms, duration: 450.ms)
            .slideY(begin: 0.1, curve: Curves.easeOutCubic),
      ],
    );
  }
}

/// Cumulative balance across the month, drawn as a curved area line.
///
/// The "draw itself" effect is a `TweenAnimationBuilder` that reveals a growing
/// prefix of the spot list — fl_chart's own implicit animation only tweens
/// between two datasets, it cannot sweep a line into existence.
class _FlowCard extends StatelessWidget {
  const _FlowCard({required this.entries, required this.month});

  final List<Entry> entries;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(month.year, month.month);

    // Net movement per day, then a running total.
    final perDay = List<double>.filled(days + 1, 0);
    for (final e in entries) {
      if (e.date.month != month.month || e.date.year != month.year) continue;
      perDay[e.date.day] += e.signed;
    }
    var running = 0.0;
    final spots = <FlSpot>[];
    for (var d = 1; d <= days; d++) {
      running += perDay[d];
      spots.add(FlSpot(d.toDouble(), running));
    }

    final scheme = Theme.of(context).colorScheme;
    final positive = running >= 0;
    final line = positive ? MP.neon : MP.flame;

    final lo = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final hi = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final pad = ((hi - lo).abs() * 0.18) + 1;

    return Glass(
      tint: line,
      padding: const EdgeInsets.fromLTRB(14, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const _CardTitle('RUNNING BALANCE'),
                Text(
                  _money.format(running),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: line,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 210,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1100),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) {
                final shown = (spots.length * t).ceil().clamp(1, spots.length);
                return LineChart(
                  LineChartData(
                    minX: 1,
                    maxX: days.toDouble(),
                    minY: lo - pad,
                    maxY: hi + pad,
                    clipData: FlClipData.all(),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: ((hi - lo).abs() / 3).clamp(1.0, 1e9),
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: scheme.onSurface.withValues(alpha: 0.06),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          interval: (days / 5).floorToDouble(),
                          getTitlesWidget: (value, meta) => Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              value.toInt().toString(),
                              style: TextStyle(
                                fontSize: 10,
                                color:
                                    scheme.onSurface.withValues(alpha: 0.35),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipColor: (_) => MP.slate,
                        tooltipRoundedRadius: 14,
                        tooltipPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        getTooltipItems: (touched) => touched
                            .map(
                              (s) => LineTooltipItem(
                                '${DateFormat('d MMM').format(DateTime(month.year, month.month, s.x.toInt()))}\n',
                                const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                                children: [
                                  TextSpan(
                                    text: _money.format(s.y),
                                    style: TextStyle(
                                      color: line,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                      getTouchedSpotIndicator: (bar, indices) => indices
                          .map(
                            (_) => TouchedSpotIndicatorData(
                              FlLine(
                                color: line.withValues(alpha: 0.4),
                                strokeWidth: 1.5,
                                dashArray: [4, 4],
                              ),
                              FlDotData(
                                getDotPainter: (a, b, c, d) =>
                                    FlDotCirclePainter(
                                  radius: 6,
                                  color: line,
                                  strokeWidth: 3,
                                  strokeColor: MP.void_,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.sublist(0, shown),
                        isCurved: true,
                        curveSmoothness: 0.28,
                        barWidth: 3,
                        color: line,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              line.withValues(alpha: 0.28),
                              line.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  // The reveal is ours; fl_chart must not also tween.
                  duration: Duration.zero,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Doughnut of outgoings by category. The touched slice grows and its figure
/// takes over the hole in the middle.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.entries,
    required this.touched,
    required this.onTouch,
    required this.total,
  });

  final List<Entry> entries;
  final int touched;
  final ValueChanged<int> onTouch;
  final double total;

  @override
  Widget build(BuildContext context) {
    final byCategory = <String, double>{};
    for (final e in entries) {
      if (e.type != EntryType.outgoing) continue;
      byCategory.update(e.category, (v) => v + e.amount,
          ifAbsent: () => e.amount);
    }
    final slices = byCategory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (slices.isEmpty) {
      return Glass(
        padding: const EdgeInsets.symmetric(vertical: 46),
        child: Center(
          child: Text(
            'No spending to break down yet.',
            style: TextStyle(
              fontSize: 13,
              color:
                  Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      );
    }

    final active = touched >= 0 && touched < slices.length ? touched : -1;

    return Glass(
      tint: MP.violet,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('WHERE IT WENT'),
          const SizedBox(height: 10),
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 62,
                    startDegreeOffset: -90,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        final idx =
                            response?.touchedSection?.touchedSectionIndex ?? -1;
                        onTouch(event is FlTapUpEvent || event is FlPanEndEvent
                            ? -1
                            : idx);
                      },
                    ),
                    sections: [
                      for (var i = 0; i < slices.length; i++)
                        PieChartSectionData(
                          value: slices[i].value,
                          color: MP.forCategory(slices[i].key),
                          radius: i == active ? 46 : 36,
                          title: '',
                          borderSide: i == active
                              ? BorderSide(
                                  color: MP.forCategory(slices[i].key)
                                      .withValues(alpha: 0.6),
                                  width: 3,
                                )
                              : BorderSide.none,
                        ),
                    ],
                  ),
                  // fl_chart tweens the radius change for us — that is the
                  // whole "slice pops out on touch" interaction.
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                ),
                _Hole(
                  label: active >= 0 ? slices[active].key : 'TOTAL',
                  value: active >= 0 ? slices[active].value : total,
                  color: active >= 0
                      ? MP.forCategory(slices[active].key)
                      : MP.flame,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < slices.length; i++)
                _LegendChip(
                  label: slices[i].key,
                  value: slices[i].value,
                  color: MP.forCategory(slices[i].key),
                  active: i == active,
                  onTap: () => onTouch(i == active ? -1 : i),
                ).animate(delay: (50 * i).ms).fadeIn(duration: 300.ms).scaleXY(
                      begin: 0.85,
                      curve: Curves.easeOutBack,
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Hole extends StatelessWidget {
  const _Hole({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
          ),
        ),
        const SizedBox(height: 4),
        // Rolls to the new figure whenever the touched slice changes.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value),
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => Text(
            _money.format(v),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    required this.label,
    required this.value,
    required this.color,
    required this.active,
    required this.onTap,
  });

  final String label;
  final double value;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withValues(alpha: active ? 0.20 : 0.08),
          border: Border.all(
            color: color.withValues(alpha: active ? 0.6 : 0.0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 6),
            Text(
              _money.format(value),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 2.4,
          fontWeight: FontWeight.w700,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45),
        ),
      );
}
