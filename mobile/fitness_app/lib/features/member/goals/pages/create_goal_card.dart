import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'date_card.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

final List<String> _goalTypeValues = [
  'Lose Weight',
  'Gain Muscle',
  'Run Distance',
  'Lift Weight',
  'Custom',
];

const List<String> _timeframeValues = [
  '1 Week',
  '2 Weeks',
  '1 Month',
  '2 Months',
  '3 Months',
  '6 Months',
  '1 Year',
  'Custom',
];

class CreateGoalCard extends ConsumerStatefulWidget {
  final VoidCallback? onGoalAdded;

  const CreateGoalCard({super.key, this.onGoalAdded});

  @override
  ConsumerState<CreateGoalCard> createState() => _CreateGoalCardState();
}

class _CreateGoalCardState extends ConsumerState<CreateGoalCard> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  String? goalType = 'Lose Weight';
  String? timeframe = '1 Month';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await SupabaseClientService().client.from('goals').insert({
      'member_id': userId,
      'title': _titleController.text.trim(),
      'target_value': double.tryParse(_targetController.text),
      'goal_type': goalType,
      'timeframe': timeframe,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': 'active',
    });
    _titleController.clear();
    _targetController.clear();
    setState(() {
      goalType = 'Lose Weight';
      timeframe = '1 Month';
      startDate = DateTime.now();
      endDate = DateTime.now().add(const Duration(days: 30));
    });
    ref.invalidate(goalsProvider);
    setState(() => _saving = false);
    widget.onGoalAdded?.call();
  }

  void _updateEndDate(String selectedTimeframe) {
    DateTime newEndDate;
    switch (selectedTimeframe) {
      case '1 Week':
        newEndDate = startDate.add(const Duration(days: 7));
        break;
      case '2 Weeks':
        newEndDate = startDate.add(const Duration(days: 14));
        break;
      case '1 Month':
        newEndDate = DateTime(startDate.year, startDate.month + 1, startDate.day);
        break;
      case '2 Months':
        newEndDate = DateTime(startDate.year, startDate.month + 2, startDate.day);
        break;
      case '3 Months':
        newEndDate = DateTime(startDate.year, startDate.month + 3, startDate.day);
        break;
      case '6 Months':
        newEndDate = DateTime(startDate.year, startDate.month + 6, startDate.day);
        break;
      case '1 Year':
        newEndDate = DateTime(startDate.year + 1, startDate.month, startDate.day);
        break;
      default:
        newEndDate = endDate;
    }
    setState(() => endDate = newEndDate);
  }

  String _getTargetLabel() {
    switch (goalType) {
      case 'Lose Weight':
        return 'Target Weight';
      case 'Gain Muscle':
        return 'Target Weight';
      case 'Run Distance':
        return 'Target Distance';
      case 'Lift Weight':
        return 'Target Weight';
      default:
        return 'Target Value';
    }
  }

  String _getTargetUnit() {
    switch (goalType) {
      case 'Run Distance':
        return 'km';
      default:
        return 'kg';
    }
  }

  String _getHelperText() {
    final value = double.tryParse(_targetController.text) ?? 0;
    switch (goalType) {
      case 'Lose Weight':
        final currentWeight = 70.0;
        final lose = (currentWeight - value).clamp(0.0, currentWeight);
        if (lose > 0) return 'You need to lose ${lose.toStringAsFixed(1)} kg';
        return 'Enter your target weight';
      case 'Gain Muscle':
        final currentWeight = 60.0;
        final gain = (value - currentWeight).clamp(0.0, 100);
        if (gain > 0) return 'You need to gain ${gain.toStringAsFixed(1)} kg';
        return 'Enter your target weight';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final helperText = _getHelperText();

    return Container(
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: primaryPurple.withAlpha(30)),
        boxShadow: [
          BoxShadow(
            color: primaryPurple.withAlpha(15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
                  child: Icon(
                    CupertinoIcons.plus_circle,
                    color: primaryPurple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create New Goal',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Define your goal and stay consistent',
                        style: TextStyle(fontSize: 13, color: textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildLabeledDropdown(
              icon: CupertinoIcons.flag,
              label: 'Goal Type',
              value: goalType,
              items: _goalTypeValues,
              onChanged: (v) => setState(() => goalType = v),
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              controller: _targetController,
              label: _getTargetLabel(),
              suffix: _getTargetUnit(),
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 6),
            if (helperText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.arrow_up,
                      size: 14,
                      color: highlightPurple,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      helperText,
                      style: TextStyle(
                        color: highlightPurple,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            _buildLabeledDropdown(
              icon: CupertinoIcons.calendar,
              label: 'Duration',
              value: timeframe,
              items: _timeframeValues,
              onChanged: (v) {
                setState(() => timeframe = v);
                if (v != null) _updateEndDate(v);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DateCard(
                    label: 'Start Date',
                    date: startDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && picked != startDate) {
                        setState(() {
                          startDate = picked;
                          if (timeframe != 'Custom') _updateEndDate(timeframe!);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DateCard(
                    label: 'End Date',
                    date: endDate,
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: endDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null && picked != endDate) {
                        setState(() => endDate = picked);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryPurple, highlightPurple],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  borderRadius: BorderRadius.circular(14),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? CupertinoActivityIndicator(color: textPrimary)
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.plus,
                              color: textPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add Goal',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledDropdown({
    required IconData icon,
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryPurple.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.transparent,
          child: DropdownButtonFormField<String>(
            initialValue: value,
            decoration: InputDecoration(
              filled: true,
              fillColor: inputDark,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
            ),
            items: items.map((String item) {
              return DropdownMenuItem<String>(
                value: item,
                child: Text(item, style: TextStyle(color: textPrimary)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryPurple.withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: primaryPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: 'Enter $label',
          placeholderStyle: TextStyle(color: textSecondary),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: inputDark,
            borderRadius: BorderRadius.circular(12),
          ),
          keyboardType: TextInputType.number,
          cursorColor: primaryPurple,
          style: TextStyle(color: textPrimary),
          suffix: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(suffix, style: TextStyle(color: textSecondary)),
                )
              : null,
        ),
      ],
    );
  }
}

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService().client
      .from('goals')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});
