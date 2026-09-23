import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shared/providers/body_measurement_provider.dart';
import '../../../shared/widgets/animations.dart' show AnimatedPulseDot;

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);
const goalSuccessGreen = Color(0xFF22C55E);
const goalWarningAmber = Color(0xFFFBBF24);
const goalDangerRed = Color(0xFFF87171);

class GoalCard extends ConsumerWidget {
  final Map<String, dynamic> goal;
  final VoidCallback? onToggleStatus;

  const GoalCard({super.key, required this.goal, this.onToggleStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = goal['title'] as String? ?? 'Untitled Goal';
    final targetValue = (goal['target_value'] as num?)?.toDouble();
    final currentValue = (goal['current_value'] as num?)?.toDouble();
    final status = goal['status'] as String? ?? 'active';
    final goalType = goal['goal_type'] as String? ?? '';
    final startDate =
        DateTime.tryParse(goal['start_date']?.toString() ?? '') ??
        DateTime.now();
    final endDate =
        DateTime.tryParse(goal['end_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 30));

    // Figure 21: live progress reads from the latest body measurement when the
    // goal has an explicit goal_type (all goals created after the feature); old
    // / seeded rows keep the stored current_value so their numbers do not move.
    final latest = ref.watch(latestBodyMeasurementProvider).valueOrNull;
    final liveWeight = (latest?['weight_kg'] as double?);
    final baselineWeight = currentValue;

    double progressPct;
    double? remaining;
    if (targetValue == null || targetValue <= 0) {
      progressPct = 0.0;
    } else if (goalType.isNotEmpty &&
        liveWeight != null &&
        baselineWeight != null) {
      final low = baselineWeight < targetValue ? baselineWeight : targetValue;
      final high = baselineWeight < targetValue ? targetValue : baselineWeight;
      if (high == low) {
        progressPct = 0.0;
      } else {
        final current = goalType.toLowerCase() == 'lose weight'
            ? high - liveWeight
            : liveWeight - low;
        progressPct = (current / (high - low) * 100.0).clamp(0.0, 100.0);
      }
      if (goalType.toLowerCase() == 'gain muscle') {
        remaining = (targetValue - liveWeight).clamp(0.0, double.infinity);
      } else if (goalType.toLowerCase() == 'lose weight') {
        remaining = (liveWeight - targetValue).clamp(0.0, double.infinity);
      } else {
        remaining = (targetValue - liveWeight).abs();
      }
    } else {
      // Legacy / seeded goals: stored current_value is authoritative.
      progressPct = (currentValue ?? 0) / targetValue * 100.0;
      if (progressPct > 100.0) progressPct = 100.0;
      remaining = targetValue - (currentValue ?? 0);
    }

    final daysRemaining = ((endDate.difference(DateTime.now()).inHours) / 24)
        .ceil();
    final isOverdue = endDate.isBefore(DateTime.now());
    final effectiveStatus = isOverdue && status == 'active'
        ? 'completed'
        : status;

    final icon = _goalIcon(goalType);
    final unitLabel = _unitLabel(goalType);
    final currentDisplay = goalType.isNotEmpty
        ? (liveWeight ?? baselineWeight)
        : currentValue;
    final remainingDisplay = remaining == null
        ? null
        : (remaining < 0 ? 0.0 : remaining);

    // Momentum-hero derived state: time progress runs alongside weight
    // progress so the member sees movement even at 0%, and days-remaining
    // gets its own urgency tier for at-a-glance reading.
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays.clamp(1, 3650);
    final elapsedDays = now.difference(startDate).inDays.clamp(0, totalDays);
    final timeProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final displayDays = daysRemaining < 0 ? 0 : daysRemaining;
    final isCompleted = effectiveStatus == 'completed';
    final daysColor = isCompleted
        ? goalSuccessGreen
        : isOverdue
        ? goalDangerRed
        : daysRemaining <= 3
        ? goalDangerRed
        : daysRemaining <= 7
        ? goalWarningAmber
        : goalSuccessGreen;
    final statusLabel = isCompleted
        ? 'COMPLETED'
        : (isOverdue ? 'EXPIRED' : 'IN PROGRESS');
    final statusColor = isCompleted
        ? goalSuccessGreen
        : (isOverdue ? textSecondary : highlightPurple);

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
                child: Icon(icon, color: highlightPurple, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                        letterSpacing: -0.41,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (goalType.isNotEmpty)
                      Text(
                        goalType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    if (targetValue != null)
                      Text(
                        'Target: ${targetValue.toStringAsFixed(1)} $unitLabel',
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
                      border: Border.all(color: statusColor.withAlpha(90)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isCompleted && !isOverdue)
                          const Padding(
                            padding: EdgeInsets.only(right: 6),
                            child: AnimatedPulseDot(
                              color: highlightPurple,
                              size: 10,
                            ),
                          ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onToggleStatus != null) ...[
                    const SizedBox(height: 8),
                    Semantics(
                      button: true,
                      label: isCompleted
                          ? 'Reopen goal'
                          : 'Mark goal as complete',
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        minimumSize: const Size(44, 44),
                        color: isCompleted
                            ? goalSuccessGreen.withAlpha(35)
                            : primaryPurple.withAlpha(35),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: () => onToggleStatus!(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isCompleted
                                  ? CupertinoIcons.refresh
                                  : CupertinoIcons.checkmark,
                              size: 14,
                              color: isCompleted
                                  ? goalSuccessGreen
                                  : highlightPurple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isCompleted ? 'Reopen' : 'Complete',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isCompleted
                                    ? goalSuccessGreen
                                    : textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
                          'Progress ${progressPct.toStringAsFixed(0)} percent of target',
                      child: SizedBox(
                        width: 140,
                        height: 140,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: (progressPct / 100).clamp(0.0, 1.0),
                          ),
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
                                  color: isCompleted
                                      ? goalSuccessGreen
                                      : highlightPurple,
                                  strokeWidth: 12,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${(value * 100).toStringAsFixed(0)}%',
                                    style: const TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 28,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const Text(
                                    'of target',
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
                    if (progressPct <= 0) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Log a weight in Progress to grow this ring',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: textSecondary, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _GoalStat(
                    label: 'Target',
                    value: targetValue != null
                        ? '${targetValue.toStringAsFixed(1)} $unitLabel'
                        : '—',
                    accent: false,
                  ),
                  _GoalStat(
                    label: 'Current',
                    value: currentDisplay != null
                        ? '${currentDisplay.toStringAsFixed(1)} $unitLabel'
                        : '—',
                    accent: false,
                  ),
                  _GoalStat(
                    label: 'To go',
                    value: remainingDisplay != null
                        ? '${remainingDisplay.toStringAsFixed(1)} $unitLabel'
                        : '—',
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
                  backgroundColor: Colors.white.withAlpha(18),
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
                style: const TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  IconData _goalIcon(String goalType) {
    switch (goalType.toLowerCase()) {
      case 'lose weight':
        return CupertinoIcons.arrow_down_right;
      case 'gain muscle':
        return Icons.fitness_center;
      case 'maintain weight':
        return Icons.balance;
      default:
        return CupertinoIcons.flag;
    }
  }

  String _unitLabel(String goalType) {
    switch (goalType.toLowerCase()) {
      case 'lose weight':
      case 'gain muscle':
      case 'maintain weight':
        return 'kg';
      default:
        return '';
    }
  }
}

/// Single stat cell inside the momentum-hero goal card: grouped by
/// proximity, not decoration (layout playbook: grouping over containers).
class _GoalStat extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _GoalStat({
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
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

/// Days-remaining banner: the screen's secondary read target, tinted by the
/// urgency tier computed in GoalCard (never neutral gray on color).
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
                  style: const TextStyle(fontSize: 12, color: textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
