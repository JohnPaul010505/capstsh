import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

const _goalSuggestions = {
  'Lose Weight': ['Log meals', 'Check in weekly'],
  'Gain Muscle': ['Log strength sessions', 'Track protein'],
  'Maintain Weight': ['Log meals', 'Log workouts'],
};

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: primaryPurple.withAlpha(15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        goalType,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: highlightPurple,
                        ),
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
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (targetValue != null)
                      Text(
                        'Target: ${targetValue.toStringAsFixed(1)} $unitLabel',
                        style: TextStyle(
                          fontSize: 15,
                          color: textSecondary,
                          letterSpacing: -0.24,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryPurple.withAlpha(20),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: (progressPct / 100).clamp(0.0, 1.0),
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: highlightPurple,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(CupertinoIcons.calendar, size: 14, color: textSecondary),
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
                        Icon(CupertinoIcons.clock, size: 14, color: textSecondary),
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
                          Icon(CupertinoIcons.chart_bar, size: 14, color: textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Remaining: ${remaining.toStringAsFixed(1)} $unitLabel',
                            style: TextStyle(color: textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    ..._goalSuggestions[goalType]?.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(CupertinoIcons.check_mark_circled, size: 14, color: highlightPurple),
                          const SizedBox(width: 8),
                          Text(s, style: TextStyle(color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    )) ?? const [],
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryPurple.withAlpha(10),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: CircularProgressIndicator(
                            value: progressPct / 100,
                            backgroundColor: primaryPurple.withAlpha(20),
                            color: highlightPurple,
                            strokeWidth: 6,
                          ),
                        ),
                        Text(
                          '${progressPct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    onPressed: () => _showLogProgress(context, goal),
                    child: Text('Log progress', style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: primaryPurple,
                    )),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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

  Future<void> _showLogProgress(BuildContext context, Map<String, dynamic> goal) async {
    final controller = TextEditingController();
    final current = (goal['current_value'] as num?)?.toDouble();
    controller.text = current != null ? current.toStringAsFixed(1) : '';

    await showModalBottomSheet(
      context: context,
      backgroundColor: ClayTokens.clayDarkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Log Progress', style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            )),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current Value',
                filled: true,
                fillColor: inputDark,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final value = double.tryParse(controller.text.trim());
                  if (value == null) return;
                  final client = SupabaseClientService().client;
                  await client
                      .from('goals')
                      .update({'current_value': value})
                      .eq('id', goal['id']);
                  if (context.mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
