import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

class GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final VoidCallback? onToggleStatus;

  const GoalCard({
    super.key,
    required this.goal,
    this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    final title = goal['title'] as String? ?? 'Untitled Goal';
    final targetValue = (goal['target_value'] as num?)?.toDouble();
    final currentValue = (goal['current_value'] as num?)?.toDouble();
    final status = goal['status'] as String? ?? 'active';
    final goalType = goal['goal_type'] as String? ?? '';
    final startDate = DateTime.tryParse(goal['start_date']?.toString() ?? '') ?? DateTime.now();
    final endDate = DateTime.tryParse(goal['end_date']?.toString() ?? '') ?? DateTime.now().add(const Duration(days: 30));

    final progressPct = targetValue != null && targetValue > 0
        ? ((currentValue ?? 0) / targetValue * 100).clamp(0.0, 100.0)
        : 0.0;
    final remaining = targetValue != null ? (targetValue - (currentValue ?? 0)) : null;
    final daysRemaining = endDate.difference(DateTime.now()).inDays;
    final isOverdue = endDate.isBefore(DateTime.now());
    final effectiveStatus = isOverdue && status == 'active' ? 'completed' : status;

    final icon = _goalIcon(goalType);
    final unitLabel = _unitLabel(goalType);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: primaryPurple, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                        letterSpacing: -0.41,
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
              CupertinoButton(
                padding: const EdgeInsets.all(8),
                onPressed: onToggleStatus != null
                    ? () => onToggleStatus!()
                    : null,
                child: Icon(
                  effectiveStatus == 'completed'
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color: effectiveStatus == 'completed'
                      ? highlightPurple
                      : primaryPurple,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(CupertinoIcons.calendar, size: 13, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '$daysRemaining days remaining',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(CupertinoIcons.clock, size: 13, color: textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                    if (remaining != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(CupertinoIcons.chart_bar, size: 13, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Remaining: ${remaining.toStringAsFixed(1)} $unitLabel',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 56,
                    height: 56,
                    child: CircularProgressIndicator(
                      value: progressPct / 100,
                      backgroundColor: primaryPurple.withAlpha(20),
                      color: highlightPurple,
                      strokeWidth: 5,
                    ),
                  ),
                  Text(
                    '${progressPct.toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
