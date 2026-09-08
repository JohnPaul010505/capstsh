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
  final bool isLast;
  final VoidCallback? onToggleStatus;

  const GoalCard({
    super.key,
    required this.goal,
    required this.isLast,
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

    final icon = _goalIcon(goalType);
    final unitLabel = _unitLabel(goalType);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryPurple.withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: primaryPurple, size: 20),
              ),
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
                          fontSize: 15,
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
                  status == 'completed'
                      ? CupertinoIcons.checkmark_circle_fill
                      : CupertinoIcons.circle,
                  color: status == 'completed'
                      ? highlightPurple
                      : primaryPurple,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) const SizedBox(height: 0.5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressPct / 100,
              backgroundColor: primaryPurple.withAlpha(20),
              color: highlightPurple,
              minHeight: 6,
            ),
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
                    if (remaining != null)
                      Text(
                        'Remaining: ${remaining.toStringAsFixed(1)} $unitLabel',
                        style: TextStyle(color: textSecondary, fontSize: 12),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      '$daysRemaining days remaining',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
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
      case 'gain weight':
        return CupertinoIcons.arrow_up_right;
      case 'build muscle':
        return Icons.fitness_center;
      case 'improve strength':
        return Icons.directions_run;
      case 'improve endurance':
        return Icons.timer;
      case 'stay active':
        return Icons.directions_walk;
      default:
        return CupertinoIcons.flag;
    }
  }

  String _unitLabel(String goalType) {
    switch (goalType.toLowerCase()) {
      case 'lose weight':
      case 'gain weight':
      case 'build muscle':
      case 'improve strength':
        return 'kg';
      case 'improve endurance':
        return 'min';
      case 'stay active':
        return 'sessions';
      default:
        return '';
    }
  }
}
