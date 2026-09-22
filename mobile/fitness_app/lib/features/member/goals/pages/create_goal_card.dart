import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/providers/body_measurement_provider.dart';
import 'package:shared/services/notification_service.dart';
import 'package:fitness_app/features/shared/services/goal_suggestion_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/animations.dart';
import 'date_card.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);
const goalFieldFill = Color(0xFF33335C);
const fieldIdleBorder = Color(0x12B4B4D0);
const fieldPlaceholder = Color(0xFFC4C4DC);
final _calendarFill = Color.alphaBlend(
  ClayTokens.clayPrimaryLight.withAlpha(25),
  ClayTokens.clayDarkBase,
);

final List<String> _goalTypeValues = [
  'Lose Weight',
  'Gain Muscle',
  'Maintain Weight',
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
  final _targetController = TextEditingController();
  String? goalType = 'Lose Weight';
  String? timeframe = '1 Month';
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;
  bool _justCreated = false;
  String? _validationMessage;
  String? _targetError;
  bool _maintainLocked = false;
  bool _suggesting = false;
  String? _aiSuggestionReason;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _validateTarget() async {
    if (_maintainLocked) return;
    final targetValue = double.tryParse(_targetController.text);
    final measurement = await _getCurrentWeightAsync();
    final currentWeight = measurement?['weight_kg'] as double?;
    if (goalType == 'Gain Muscle' &&
        targetValue != null &&
        currentWeight != null) {
      if (targetValue <= currentWeight) {
        setState(
          () => _targetError =
              'Target must be above your current weight (${currentWeight.toStringAsFixed(1)} kg).',
        );
        return;
      }
    }
    if (goalType == 'Lose Weight' &&
        targetValue != null &&
        currentWeight != null) {
      if (targetValue >= currentWeight) {
        setState(
          () => _targetError =
              'Target must be below your current weight (${currentWeight.toStringAsFixed(1)} kg).',
        );
        return;
      }
    }
    setState(() => _targetError = null);
  }

  Future<Map<String, dynamic>?> _getCurrentWeightAsync() async {
    final async = ref.read(latestBodyMeasurementProvider.future);
    return async;
  }

  Future<double?> _getCurrentWeight() async {
    final measurement = await _getCurrentWeightAsync();
    return measurement?['weight_kg'] as double?;
  }

  /// Figure 26 «include» Generate Goal Suggestion: prefill the target from the
  /// AI service (deterministic fallback when Gemini is unavailable).
  Future<void> _suggestTarget() async {
    final userId = SupabaseClientService().client.auth.currentUser?.id;
    if (userId == null) return;
    setState(() {
      _suggesting = true;
      _aiSuggestionReason = null;
    });
    try {
      final suggestions = await GoalSuggestionService().getSuggestions(userId);
      if (!mounted) return;
      if (suggestions.isEmpty) {
        setState(() => _aiSuggestionReason =
            'No suggestion available yet — log measurements and workouts first.');
        return;
      }
      // Prefer a suggestion that matches the selected goal type when possible.
      final key = (goalType ?? '').toLowerCase();
      GoalSuggestion pick = suggestions.first;
      for (final s in suggestions) {
        final t = s.goalType.toLowerCase();
        if ((key.contains('lose') && t.contains('lose')) ||
            (key.contains('gain') && t.contains('gain')) ||
            (key.contains('maintain') && t.contains('maintain'))) {
          pick = s;
          break;
        }
      }
      setState(() {
        if (pick.suggestedValue > 0 && !_maintainLocked) {
          _targetController.text = pick.suggestedValue.toStringAsFixed(1);
        }
        _aiSuggestionReason = pick.reason;
      });
      await _validateTarget();
    } finally {
      if (mounted) setState(() => _suggesting = false);
    }
  }

  Future<void> _save() async {
    final title = '${goalType ?? 'Fitness'} goal';
    final targetValue = double.tryParse(_targetController.text);
    if (targetValue == null || targetValue <= 0) {
      setState(
        () => _validationMessage = 'Enter a target weight greater than zero.',
      );
      return;
    }
    if (_targetError != null) {
      setState(() => _validationMessage = _targetError);
      return;
    }
    setState(() {
      _saving = true;
      _validationMessage = null;
    });
    try {
      if (goalType == 'Gain Muscle') {
        final currentWeight = await _getCurrentWeight();
        if (currentWeight != null && targetValue <= currentWeight) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: ClayTokens.clayDarkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Adjust target weight',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Your current weight is ${currentWeight.toStringAsFixed(1)} kg. For "Gain Muscle", choose a target above that.',
                  style: const TextStyle(color: Color(0xFFB4B4D0)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Color(0xFFD6A5FF)),
                    ),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }
      if (goalType == 'Lose Weight') {
        final currentWeight = await _getCurrentWeight();
        if (currentWeight != null && targetValue >= currentWeight) {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: ClayTokens.clayDarkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Adjust target weight',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Your current weight is ${currentWeight.toStringAsFixed(1)} kg. For "Lose Weight", choose a target below that.',
                  style: const TextStyle(color: Color(0xFFB4B4D0)),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'OK',
                      style: TextStyle(color: Color(0xFFD6A5FF)),
                    ),
                  ),
                ],
              ),
            );
          }
          return;
        }
      }

      final userId = SupabaseClientService().client.auth.currentUser!.id;
      await SupabaseClientService().client.from('goals').insert({
        'member_id': userId,
        'title': title,
        'target_value': targetValue,
        'goal_type': goalType,
        'timeframe': timeframe,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'active',
      });

      await NotificationService().createNotification(
        userId: userId,
        title: 'Goal Created',
        body: 'Your $goalType goal has been created successfully.',
      );

      _targetController.clear();
      setState(() {
        goalType = 'Lose Weight';
        timeframe = '1 Month';
        startDate = DateTime.now();
        endDate = DateTime.now().add(const Duration(days: 30));
        _justCreated = true;
        _maintainLocked = false;
        _targetError = null;
      });
      ref.invalidate(goalsProvider);
      widget.onGoalAdded?.call();
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _justCreated = false);
    } catch (e) {
      if (mounted) {
        setState(
          () => _validationMessage = 'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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

  String _getTargetLabel() {
    switch (goalType) {
      case 'Lose Weight':
      case 'Gain Muscle':
      case 'Maintain Weight':
        return 'Target Weight';
      default:
        return 'Target Value';
    }
  }

  String _getTargetUnit() {
    return 'kg';
  }

  Widget _calendarBuilder(BuildContext context, Widget? child) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF7C3AED),
          onPrimary: Color(0xFFFFFFFF),
          surface: Color(0xFF26233F),
          onSurface: Color(0xFFECECFC),
          onSurfaceVariant: Color(0xFFB4B4D0),
        ),
        scaffoldBackgroundColor: _calendarFill,
        datePickerTheme: DatePickerThemeData(
          backgroundColor: _calendarFill,
          headerBackgroundColor: _calendarFill,
          headerForegroundColor: const Color(0xFFFFFFFF),
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: 0,
      child: ClayCard(
        variant: ClayCardVariant.outlined,
        backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
        customPadding: const EdgeInsets.all(20),
        padding: ClayCardPadding.none,
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
                child: const Row(
                  children: [
                    Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: Color(0xFF22C55E),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Goal created',
                      style: TextStyle(
                        color: Colors.white,
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
                    'Create a goal',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
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
                  style: const TextStyle(
                    color: Color(0xFFFCA5A5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            _buildLabeledDropdown(
              label: 'Goal Type',
              value: goalType,
              items: _goalTypeValues,
              onChanged: (v) async {
                setState(() {
                  goalType = v;
                  _targetError = null;
                  _maintainLocked = false;
                });
                if (v == 'Maintain Weight') {
                  final weight = await _getCurrentWeight();
                  if (weight != null) {
                    setState(() {
                      _targetController.text = weight.toStringAsFixed(1);
                      _maintainLocked = true;
                    });
                  }
                } else {
                  setState(() {
                    _targetController.clear();
                    _maintainLocked = false;
                  });
                }
                await _validateTarget();
              },
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              controller: _targetController,
              label: _getTargetLabel(),
              suffix: _getTargetUnit(),
              placeholder: 'Enter your target',
              enabled: !_maintainLocked,
              onChanged: (_) => _validateTarget(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: _suggesting ? null : _suggestTarget,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primaryPurple.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_suggesting)
                          const CupertinoActivityIndicator(radius: 7)
                        else
                          const Icon(Icons.auto_awesome, size: 14, color: highlightPurple),
                        const SizedBox(width: 6),
                        Text(
                          _suggesting ? 'Thinking...' : 'Suggest target with AI',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: highlightPurple,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_aiSuggestionReason != null) ...[
              const SizedBox(height: 8),
              Text(
                _aiSuggestionReason!,
                style: const TextStyle(fontSize: 12, color: textSecondary),
              ),
            ],
            if (_targetError != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    CupertinoIcons.exclamationmark_circle,
                    color: Color(0xFFEF4444),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _targetError!,
                      style: const TextStyle(
                        color: Color(0xFFFCA5A5),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            _buildLabeledDropdown(
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
                      ? CupertinoActivityIndicator(color: textPrimary)
                      : Text(
                          'Add Goal',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
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

  Widget _buildLabeledDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
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
        DropdownField(value: value, items: items, onChanged: onChanged),
      ],
    );
  }

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? suffix,
    required String placeholder,
    bool enabled = true,
    ValueChanged<String>? onChanged,
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
          keyboardType: suffix == null
              ? TextInputType.text
              : const TextInputType.numberWithOptions(decimal: true),
          enabled: enabled,
          cursorColor: primaryPurple,
          style: TextStyle(color: enabled ? textPrimary : textSecondary),
          inputFormatters: enabled
              ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$'))]
              : null,
          suffix: suffix != null
              ? Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text(suffix, style: TextStyle(color: fieldPlaceholder)),
                )
              : null,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class DropdownField extends StatefulWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const DropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<DropdownField> createState() => _DropdownFieldState();
}

class _DropdownFieldState extends State<DropdownField> {
  bool _open = false;
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  void _openMenu() {
    if (_overlayEntry != null) return;
    setState(() => _open = true);
    _overlayEntry = _buildOverlay();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _close() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (_open) setState(() => _open = false);
  }

  OverlayEntry _buildOverlay() {
    final box = context.findRenderObject() as RenderBox;
    final targetLocal = box.localToGlobal(Offset.zero);
    final screenHeight = MediaQuery.of(context).size.height;
    final spaceBelow = screenHeight - targetLocal.dy - box.size.height;
    final menuHeight = widget.items.length * 52.0 + 12;

    return OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _layerLink,
            offset: Offset.zero,
            showWhenUnlinked: false,
            child: _DropdownMenu(
              value: widget.value,
              items: widget.items,
              onChanged: (value) {
                widget.onChanged(value);
                _close();
              },
              width: box.size.width,
              prefersBelow: spaceBelow >= menuHeight,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _openMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: goalFieldFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _open ? primaryPurple.withAlpha(80) : fieldIdleBorder,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.value ?? 'Select...',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: fieldPlaceholder,
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DropdownMenu extends StatelessWidget {
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final double width;
  final bool prefersBelow;

  const _DropdownMenu({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
    required this.prefersBelow,
  });

  @override
  Widget build(BuildContext context) {
    final menu = Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: goalFieldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fieldIdleBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (item) => _MenuItem(
                  item: item,
                  isSelected: item == value,
                  onTap: () => onChanged(item),
                ),
              )
              .toList(),
        ),
      ),
    );

    if (prefersBelow) {
      return menu;
    }

    final overlay = Overlay.of(context);
    final box = overlay.context.findRenderObject() as RenderBox?;
    final top = box?.localToGlobal(Offset.zero).dy ?? 0;
    final estimatedHeight = items.length * 52.0 + 12;
    final flippedTop = (top - estimatedHeight).clamp(0.0, top);

    return Positioned(top: flippedTop, left: 0, child: menu);
  }
}

class _MenuItem extends StatelessWidget {
  final String item;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? primaryPurple.withAlpha(15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? textPrimary : fieldPlaceholder,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: highlightPurple,
                size: 18,
              ),
          ],
        ),
      ),
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
