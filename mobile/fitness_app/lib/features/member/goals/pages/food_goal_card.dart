import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design_tokens.dart';
import '../providers/food_goal_provider.dart';
import '../services/goal_home_widget.dart';

const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const goalSuccessGreen = Color(0xFF22C55E);
const goalWarningAmber = Color(0xFFFBBF24);
const goalDangerRed = Color(0xFFF87171);

// Brightness-aware ink matching goal_card.dart's glass panel.
Color get textPrimary => ClayTokens.clayDarkTextPrimary;
Color get textSecondary => ClayTokens.clayDarkTextSecondary;

/// The Food tab's twin of GoalCard: a running calorie goal rendered with the
/// same hero ring, stat row, days banner and time bar. The ring shows TODAY's
/// consumed calories against the DAILY target (not weight), so it reads from
/// [todayCaloriesProvider] and recomputes as meals are logged.
class FoodGoalCard extends ConsumerWidget {
  final Map<String, dynamic> goal;
  final VoidCallback? onCancel;

  const FoodGoalCard({
    super.key,
    required this.goal,
    this.onCancel,
  });

  String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetValue = (goal['target_value'] as num?)?.toDouble();
    final status = goal['status'] as String? ?? 'active';
    final startDate =
        DateTime.tryParse(goal['start_date']?.toString() ?? '') ??
        DateTime.now();
    final endDate =
        DateTime.tryParse(goal['end_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 30));

    final consumedToday = ref.watch(todayCaloriesProvider).valueOrNull ?? 0;
    final dailyTarget = targetValue ?? 0;

    // Ring progress = today's intake vs the daily target (capped at 100%).
    final ringPct = dailyTarget > 0
        ? (consumedToday / dailyTarget).clamp(0.0, 1.0)
        : 0.0;
    final remaining = (dailyTarget - consumedToday).round();
    final isOver = remaining < 0;

    final daysRemaining =
        ((endDate.difference(DateTime.now()).inHours) / 24).ceil();
    final isOverdue = endDate.isBefore(DateTime.now());
    final effectiveStatus =
        isOverdue && status == 'active' ? 'completed' : status;
    final isCompleted = effectiveStatus == 'completed';
    final isCancelled = status == 'cancelled';

    // Time-window progress (same math as GoalCard) for the bottom bar.
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays.clamp(1, 3650);
    final elapsedDays = now.difference(startDate).inDays.clamp(0, totalDays);
    final timeProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final displayDays = daysRemaining < 0 ? 0 : daysRemaining;

    final daysColor = isCompleted
        ? goalSuccessGreen
        : isOverdue
        ? goalDangerRed
        : daysRemaining <= 3
        ? goalDangerRed
        : daysRemaining <= 7
        ? goalWarningAmber
        : goalSuccessGreen;
    final statusLabel = isCancelled
        ? 'CANCELLED'
        : isCompleted
        ? 'COMPLETED'
        : (isOverdue ? 'EXPIRED' : 'IN PROGRESS');
    final statusColor = isCancelled
        ? goalDangerRed
        : isCompleted
        ? goalSuccessGreen
        : (isOverdue ? textSecondary : highlightPurple);
    final ringColor = isCompleted
        ? goalSuccessGreen
        : (isOver ? goalWarningAmber : highlightPurple);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryPurple.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  CupertinoIcons.flame_fill,
                  color: highlightPurple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Daily calorie goal',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.41,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'CALORIE INTAKE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Target: ${dailyTarget.toStringAsFixed(0)} kcal/day',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                        letterSpacing: -0.24,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(28),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withAlpha(70)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Semantics(
                      label:
                          'Today ${(ringPct * 100).toStringAsFixed(0)} percent of daily target',
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: ringPct),
                          duration: const Duration(milliseconds: 900),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, _) => Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 140,
                                height: 140,
                                child: CircularProgressIndicator(
                                  value: value,
                                  backgroundColor: primaryPurple.withAlpha(28),
                                  color: ringColor,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(value * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 28,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  Text(
                                    'of today',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      dailyTarget <= 0
                          ? 'No daily target set'
                          : (isOver
                                ? 'Over by ${-remaining} kcal today'
                                : '$remaining kcal left today'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: dailyTarget <= 0
                            ? textSecondary
                            : (isOver ? goalWarningAmber : textSecondary),
                        fontSize: 13,
                        fontWeight: isOver
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _FoodGoalStat(
                    label: 'Target',
                    value: '${dailyTarget.toStringAsFixed(0)} kcal',
                    accent: false,
                  ),
                  _FoodGoalStat(
                    label: 'Today',
                    value: '$consumedToday kcal',
                    accent: false,
                  ),
                  _FoodGoalStat(
                    label: isOver ? 'Over' : 'Left',
                    value: '${isOver ? -remaining : remaining} kcal',
                    accent: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DaysBanner(
                displayDays: displayDays,
                daysColor: daysColor,
                dateRange:
                    '${_shortDate(startDate)} – ${_shortDate(endDate)}, ${endDate.year}',
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: timeProgress,
                  minHeight: 8,
                  backgroundColor: ClayTokens.hairline.withAlpha(18),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isCompleted ? goalSuccessGreen : highlightPurple,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isOverdue && !isCompleted
                    ? 'Ended ${_shortDate(endDate)}, ${endDate.year}'
                    : 'Day $elapsedDays of $totalDays',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              if (status == 'active' && !isOverdue && !isCancelled) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed: () async {
                      // Best-effort: a data/render hiccup must never stop the
                      // member from pinning the widget, which is what they
                      // asked for (mirrors GoalCard's workout button).
                      try {
                        await GoalHomeWidget.syncFoodGoal(
                          goal,
                          consumedToday: consumedToday,
                        );
                      } catch (error) {
                        debugPrint('Food goal widget sync failed: $error');
                      }
                      try {
                        final requested = await GoalHomeWidget.requestFoodPin();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              requested
                                  ? 'Follow the phone prompt to add your food goal to the home screen.'
                                  : 'Your Android launcher does not support adding this widget directly. Long-press the home screen and choose Widgets.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Could not add widget: $error'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(
                      CupertinoIcons.device_phone_portrait,
                      size: 17,
                    ),
                    label: const Text('Add to Home Screen'),
                    style: FilledButton.styleFrom(
                      backgroundColor: highlightPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
              ],
              if (onCancel != null && !isCompleted && !isOverdue) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: onCancel,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    icon: const Icon(CupertinoIcons.xmark_circle, size: 16),
                    label: const Text('Cancel goal'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FoodGoalStat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _FoodGoalStat({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: accent ? highlightPurple : textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Days-remaining banner — identical styling to goal_card.dart's _DaysBanner.
class _DaysBanner extends StatelessWidget {
  final int displayDays;
  final Color daysColor;
  final String dateRange;

  const _DaysBanner({
    required this.displayDays,
    required this.daysColor,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: daysColor.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: daysColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: daysColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(CupertinoIcons.calendar, size: 18, color: daysColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$displayDays',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: daysColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        displayDays == 1 ? 'day left' : 'days left',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: daysColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateRange,
                  style: TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
