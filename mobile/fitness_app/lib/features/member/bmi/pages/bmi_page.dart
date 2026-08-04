import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../data/bmi_info.dart';
import '../providers/bmi_history_provider.dart';

/// BMI page: shows the member's current BMI (from the onboarding value) plus a
/// growth-over-time chart built from every recorded body measurement.
class BmiPage extends ConsumerWidget {
  const BmiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(bmiHistoryProvider);

    return CupertinoPageScaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Expanded(
              child: historyAsync.when(
                data: (history) => ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    if (history.isNotEmpty) ...[
                      _buildHeroCard(history.last),
                      const SizedBox(height: 16),
                    ],
                    _buildChartCard(history),
                    const SizedBox(height: 16),
                    _buildRecordButton(context),
                    const SizedBox(height: 24),
                  ],
                ),
                loading: () => const Center(child: CupertinoActivityIndicator()),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.back, color: Color(0xFF7C3AED)),
          ),
          Expanded(
            child: Text(
              'BMI',
              textAlign: TextAlign.center,
              style: ClayTokens.titleLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }

  Widget _buildHeroCard(BmiInfo latest) {
    final color = bmiCategoryColor(latest.bmi);
    return StaggeredFadeIn(
      index: 0,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClayTokens.clayDarkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('CURRENT BMI', style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withAlpha(60)),
                  ),
                  child: Text(
                    latest.label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: ClayTokens.normal,
              transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
              child: Text(
                latest.bmi.toStringAsFixed(1),
                key: ValueKey(latest.bmi.toStringAsFixed(1)),
                style: ClayTokens.darkDisplayMedium.copyWith(fontSize: 44, color: color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Updated ${DateFormat('MMM d, yyyy').format(latest.measuredAt)}',
              style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartCard(List<BmiInfo> history) {
    return StaggeredFadeIn(
      index: 1,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClayTokens.clayDarkBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'GROWTH OVER TIME',
                style: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
              ),
            ),
            SizedBox(
              height: 220,
              child: history.length < 2
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.show_chart, color: Color(0xFF7070A0), size: 28),
                          const SizedBox(height: 8),
                          Text(
                            'Record another measurement to see your trend',
                            textAlign: TextAlign.center,
                            style: ClayTokens.darkBodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary),
                          ),
                        ],
                      ),
                    )
                  : _BmiLineChart(history: history),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordButton(BuildContext context) {
    return StaggeredFadeIn(
      index: 2,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC56BF0).withAlpha(60),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextButton(
          onPressed: () => context.push('/member/measurements'),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 6),
              Text(
                'Record new measurement',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BmiLineChart extends StatelessWidget {
  final List<BmiInfo> history;

  const _BmiLineChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[
      for (var i = 0; i < history.length; i++) FlSpot(i.toDouble(), history[i].bmi),
    ];
    final values = history.map((h) => h.bmi).toList();
    final minBmi = values.reduce((a, b) => a < b ? a : b);
    final maxBmi = values.reduce((a, b) => a > b ? a : b);
    final minY = (minBmi - 1).floorToDouble();
    final maxY = (maxBmi + 1).ceilToDouble();
    final color = bmiCategoryColor(history.last.bmi);

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (history.length - 1).toDouble(),
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (_) => FlLine(
            color: ClayTokens.clayDarkBorder.withValues(alpha: 0.6),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                textAlign: TextAlign.right,
                style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary, fontSize: 9),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= history.length) return const SizedBox.shrink();
                final hideMiddle = history.length > 4 && i != 0 && i != history.length - 1;
                if (hideMiddle) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('MMM d').format(history[i].measuredAt),
                    style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary, fontSize: 9),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final i = spot.x.toInt();
              return LineTooltipItem(
                '${DateFormat('MMM d, yyyy').format(history[i].measuredAt)}\nBMI ${history[i].bmi.toStringAsFixed(1)}',
                ClayTokens.labelSmall.copyWith(
                  color: ClayTokens.clayDarkTextInverse,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.25,
            color: color,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: color,
                strokeWidth: 2,
                strokeColor: ClayTokens.clayDarkSurface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.25),
                  color.withValues(alpha: 0.02),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
