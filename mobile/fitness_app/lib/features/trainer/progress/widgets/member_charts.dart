import 'package:flutter/material.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay_area_chart.dart';

/// Public, reusable copies of the three Member Progress charts that used to
/// live private inside `member_progress_page.dart`. The 4-tab Member Progress
/// shell embeds these in its Overview tab; the old single-screen page still
/// keeps its own private copies, so both paths stay independent.

const monthShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// This Week: completed workout sessions per weekday (Mon–Sun). Tapping a bar
/// grows it and shows that day's count.
class MemberWeekChart extends StatefulWidget {
  final List<int> weekCounts;
  final int maxCount;

  const MemberWeekChart({
    super.key,
    required this.weekCounts,
    required this.maxCount,
  });

  @override
  State<MemberWeekChart> createState() => _MemberWeekChartState();
}

class _MemberWeekChartState extends State<MemberWeekChart> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1;

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This Week',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ClayTokens.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          if (_selectedDay != null)
            Text(
              '${labels[_selectedDay!]}: ${widget.weekCounts[_selectedDay!]} workout${widget.weekCounts[_selectedDay!] == 1 ? '' : 's'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'Tap a bar for details',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = widget.weekCounts[i];
                final pct = widget.maxCount > 0 ? (count / widget.maxCount) : 0.0;
                final barHeight = (pct * 52).clamp(2.0, 52.0);
                final isFuture = i > today;
                final isSelected = i == _selectedDay;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _selectedDay = _selectedDay == i ? null : i,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: isSelected
                          ? (barHeight + 6).clamp(2.0, 58.0)
                          : barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                        color: isFuture
                            ? ClayTokens.clayDarkTextTertiary.withAlpha(50)
                            : ClayTokens.clayPrimaryDark,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: List.generate(7, (i) {
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// This Month: attendance check-ins per calendar month for the current year.
class MemberMonthChart extends StatelessWidget {
  final List<int> monthlyCounts;

  const MemberMonthChart({super.key, required this.monthlyCounts});

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now().month - 1;
    final values = List<double?>.generate(12, (i) {
      if (i > current) return null;
      if (i == current && monthlyCounts[i] == 0) return null;
      return monthlyCounts[i].toDouble();
    });

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'This Month',
                        style: ClayTokens.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateTime.now().year.toString(),
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: ClayTypography.headingFamily,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFA78BFA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Check-ins per month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: ${monthlyCounts.reduce((a, b) => a + b)}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClayAreaChart(
            values: values,
            labels: monthShort,
            strokeColor: ClayTokens.clayPrimaryDark,
            showYAxis: false,
            showValueLabels: true,
            dotColor: ClayTokens.clayPrimary,
            dotRingColor: ClayTokens.clayPrimaryDark,
          ),
        ],
      ),
    );
  }
}

/// Growth Over Time: BMI per month (derived from weight + height).
class MemberGrowthChart extends StatelessWidget {
  final List<double?> monthlyWeights;

  const MemberGrowthChart({super.key, required this.monthlyWeights});

  @override
  Widget build(BuildContext context) {
    final weights = monthlyWeights.whereType<double>().toList();
    final latestWeight = weights.isEmpty ? null : weights.last;

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Growth Over Time',
                    style: ClayTokens.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BMI per month',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: ClayTypography.headingFamily,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (latestWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    latestWeight.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClayAreaChart(
            values: monthlyWeights,
            labels: monthShort,
            strokeColor: ClayTokens.clayPrimaryDark,
            emptyMessage: 'No BMI data yet',
            showValueLabels: true,
            dotColor: ClayTokens.clayPrimary,
            dotRingColor: ClayTokens.clayPrimaryDark,
          ),
        ],
      ),
    );
  }
}

