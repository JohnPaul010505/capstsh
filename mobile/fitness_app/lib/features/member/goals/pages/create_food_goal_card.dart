import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/glass_card.dart';
import 'create_goal_card.dart' show DropdownField;
import 'date_card.dart';
import '../providers/food_goal_provider.dart';

const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);

// Brightness-aware ink, identical to create_goal_card.dart so the two forms
// read the same on the shared glass panel (dark ink in light mode).
Color get textPrimary => ClayTokens.clayDarkTextPrimary;
Color get textSecondary => ClayTokens.clayDarkTextSecondary;
Color get goalFieldFill =>
    ClayColors.isLightMode ? Colors.white : const Color(0xFF33335C);
const fieldIdleBorder = Color(0x12B4B4D0);
Color get fieldPlaceholder => ClayColors.isLightMode
    ? ClayTokens.clayTextTertiary
    : const Color(0xFFC4C4DC);

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

/// "Create a food goal" form — the Food tab's twin of CreateGoalCard. The
/// member sets a DAILY calorie target over a time window; it is stored as a
/// food-category goal (target_value = daily kcal, unit 'kcal/day') and drives
/// the Food Intake ring.
class CreateFoodGoalCard extends ConsumerStatefulWidget {
  final VoidCallback? onGoalAdded;

  /// True while another FOOD goal is still running — the form stays visible but
  /// _save() refuses the insert with a clear hint (one goal per category).
  final bool hasActiveGoal;

  const CreateFoodGoalCard({
    super.key,
    this.onGoalAdded,
    this.hasActiveGoal = false,
  });

  @override
  ConsumerState<CreateFoodGoalCard> createState() => _CreateFoodGoalCardState();
}

class _CreateFoodGoalCardState extends ConsumerState<CreateFoodGoalCard> {
  final _targetController = TextEditingController();
  String? timeframe = '1 Month';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  bool _justCreated = false;
  String? _validationMessage;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  String _dateOnly(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  void _updateEndDate(String selectedTimeframe) {
    DateTime newEndDate;
    switch (selectedTimeframe) {
      case '1 Week':
        newEndDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + 7,
        );
        break;
      case '2 Weeks':
        newEndDate = DateTime(
          startDate.year,
          startDate.month,
          startDate.day + 14,
        );
        break;
      case '1 Month':
        newEndDate = DateTime(
          startDate.year,
          startDate.month + 1,
          startDate.day,
        );
        break;
      case '2 Months':
        newEndDate = DateTime(
          startDate.year,
          startDate.month + 2,
          startDate.day,
        );
        break;
      case '3 Months':
        newEndDate = DateTime(
          startDate.year,
          startDate.month + 3,
          startDate.day,
        );
        break;
      case '6 Months':
        newEndDate = DateTime(
          startDate.year,
          startDate.month + 6,
          startDate.day,
        );
        break;
      case '1 Year':
        newEndDate = DateTime(
          startDate.year + 1,
          startDate.month,
          startDate.day,
        );
        break;
      default:
        newEndDate = endDate;
    }
    setState(() => endDate = newEndDate);
  }

  Future<void> _save() async {
    if (widget.hasActiveGoal) {
      setState(
        () => _validationMessage =
            'You currently have a food goal, complete that first.',
      );
      return;
    }
    final targetValue = double.tryParse(_targetController.text.trim());
    if (targetValue == null || targetValue <= 0) {
      setState(
        () => _validationMessage = 'Enter a daily calorie target above zero.',
      );
      return;
    }
    if (endDate.isBefore(startDate)) {
      setState(
        () => _validationMessage = 'End date must be after the start date.',
      );
      return;
    }
    setState(() {
      _saving = true;
      _validationMessage = null;
    });
    try {
      final userId = SupabaseClientService().client.auth.currentUser!.id;
      final params = <String, dynamic>{
        'member_id': userId,
        'title': 'Daily calorie goal',
        'goal_type': 'Calorie Intake',
        'goal_category': 'food',
        'target_value': targetValue,
        'current_value': 0,
        'unit': 'kcal/day',
        'timeframe': timeframe,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'status': 'active',
      };
      await SupabaseClientService().client.from('goals').insert(params);

      // Refresh the running food goal + today's calories so the card and the
      // Food Intake ring pick up the new target immediately.
      ref.invalidate(activeFoodGoalProvider);
      ref.invalidate(todayCaloriesProvider);

      try {
        await NotificationService().createNotification(
          userId: userId,
          title: 'Food Goal Created',
          body:
              'Your daily calorie goal of ${targetValue.toStringAsFixed(0)} kcal has been created.',
        );
      } catch (e) {
        debugPrint('FOOD GOAL NOTIFY failed: $e');
      }

      _targetController.clear();
      setState(() {
        timeframe = '1 Month';
        startDate = DateTime.now();
        endDate = DateTime.now().add(const Duration(days: 30));
        _justCreated = true;
      });
      widget.onGoalAdded?.call();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _justCreated = false);
    } catch (e) {
      debugPrint('FOOD GOAL SAVE failed: $e');
      if (mounted) {
        setState(
          () => _validationMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _calendarBuilder(BuildContext context, Widget? child) {
    final isLight = ClayColors.isLightMode;
    final calendarFill = isLight
        ? const Color(0xFFF5F1FF)
        : const Color(0xFF26233F);
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: isLight
            ? const ColorScheme.light(
                primary: Color(0xFF7C3AED),
                onPrimary: Color(0xFFFFFFFF),
                surface: Color(0xFFFFFFFF),
                onSurface: Color(0xFF332F3A),
                onSurfaceVariant: Color(0xFF635F69),
              )
            : const ColorScheme.dark(
                primary: Color(0xFF7C3AED),
                onPrimary: Color(0xFFFFFFFF),
                surface: Color(0xFF26233F),
                onSurface: Color(0xFFECECFC),
                onSurfaceVariant: Color(0xFFB4B4D0),
              ),
        scaffoldBackgroundColor: calendarFill,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: calendarFill,
          headerBackgroundColor: calendarFill,
          headerForegroundColor: isLight
              ? const Color(0xFF332F3A)
              : const Color(0xFFFFFFFF),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    required String suffix,
    required String placeholder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: textPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        CupertinoTextField(
          controller: controller,
          placeholder: placeholder,
          placeholderStyle: TextStyle(color: fieldPlaceholder),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: goalFieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldIdleBorder),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: false),
          cursorColor: primaryPurple,
          style: TextStyle(color: textPrimary),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          suffix: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(suffix, style: TextStyle(color: fieldPlaceholder)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: 0,
      child: MemberGlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_justCreated)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF22C55E).withAlpha(40),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: Color(0xFF22C55E),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Food goal created',
                      style: TextStyle(
                        color: ClayTokens.clayDarkTextPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a food goal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set a daily calorie target to track against your food intake.',
                    style: TextStyle(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            const SizedBox(height: 20),
            if (_validationMessage != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _validationMessage!,
                  style: TextStyle(
                    color: ClayColors.isLightMode
                        ? ClayTokens.clayError
                        : const Color(0xFFFCA5A5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildLabeledField(
              controller: _targetController,
              label: 'Daily Calorie Target',
              suffix: 'kcal',
              placeholder: 'e.g. 2000',
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Duration',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownField(
                  value: timeframe,
                  items: _timeframeValues,
                  onChanged: (v) {
                    setState(() => timeframe = v);
                    if (v != null) _updateEndDate(v);
                  },
                ),
              ],
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
                        barrierColor: Colors.transparent,
                        builder: _calendarBuilder,
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
                        barrierColor: Colors.transparent,
                        builder: _calendarBuilder,
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
                      ? CupertinoActivityIndicator(
                          color: ClayColors.isLightMode
                              ? Colors.white
                              : textPrimary,
                        )
                      : Text(
                          'Add Goal',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: ClayColors.isLightMode
                                ? Colors.white
                                : textPrimary,
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
}
