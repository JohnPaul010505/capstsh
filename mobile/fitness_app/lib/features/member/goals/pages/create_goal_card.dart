import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
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

IconData _goalTypeIcon(String type) {
  switch (type) {
    case 'Lose Weight':
      return CupertinoIcons.arrow_down_right;
    case 'Gain Muscle':
      return Icons.fitness_center;
    case 'Maintain Weight':
      return Icons.balance;
    default:
      return CupertinoIcons.flag;
  }
}

IconData _timeframeIcon(String timeframe) {
  switch (timeframe) {
    case '1 Week':
    case '2 Weeks':
      return CupertinoIcons.clock;
    case '1 Month':
    case '2 Months':
    case '3 Months':
    case '6 Months':
    case '1 Year':
      return CupertinoIcons.calendar;
    case 'Custom':
      return CupertinoIcons.slider_horizontal_3;
    default:
      return CupertinoIcons.calendar;
  }
}

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
  bool _justCreated = false;

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final targetValue = double.tryParse(_targetController.text);
    if (goalType == 'Gain Muscle' && targetValue != null) {
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
        setState(() => _saving = false);
        return;
      }
    }
    final userId = SupabaseClientService().client.auth.currentUser!.id;
    await SupabaseClientService().client.from('goals').insert({
      'member_id': userId,
      'title': _titleController.text.trim(),
      'target_value': targetValue,
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
      _justCreated = true;
    });
    ref.invalidate(goalsProvider);
    setState(() => _saving = false);
    widget.onGoalAdded?.call();
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _justCreated = false);
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

  Future<double?> _getCurrentWeight() async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser!.id;
    final rows = await client
        .from('body_measurements')
        .select('weight_kg')
        .eq('member_id', userId)
        .order('measured_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final v = rows.first['weight_kg'];
    if (v is num) return v.toDouble();
    return null;
  }

  @override
  Widget build(BuildContext context) {
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
                  Column(
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
                ],
              ),
            const SizedBox(height: 20),
            _buildLabeledDropdown(
              icon: CupertinoIcons.flag,
              label: 'Goal Type',
              value: goalType,
              items: _goalTypeValues,
              iconBuilder: _goalTypeIcon,
              onChanged: (v) => setState(() => goalType = v),
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              controller: _targetController,
              label: _getTargetLabel(),
              suffix: _getTargetUnit(),
              icon: Icons.fitness_center,
            ),
            const SizedBox(height: 16),
            _buildLabeledDropdown(
              icon: CupertinoIcons.calendar,
              label: 'Duration',
              value: timeframe,
              items: _timeframeValues,
              iconBuilder: _timeframeIcon,
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
    required IconData Function(String) iconBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: textSecondary, size: 16),
            const SizedBox(width: 10),
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
        DropdownField(
          value: value,
          items: items,
          iconBuilder: iconBuilder,
          onChanged: onChanged,
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

class DropdownField extends StatefulWidget {
  final String? value;
  final List<String> items;
  final IconData Function(String) iconBuilder;
  final ValueChanged<String?> onChanged;

  const DropdownField({
    super.key,
    required this.value,
    required this.items,
    required this.iconBuilder,
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
              iconBuilder: widget.iconBuilder,
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
            color: inputDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _open ? primaryPurple.withAlpha(80) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                widget.iconBuilder(widget.value ?? ''),
                color: highlightPurple,
                size: 16,
              ),
              const SizedBox(width: 10),
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
                  color: textSecondary,
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
  final IconData Function(String) iconBuilder;
  final ValueChanged<String?> onChanged;
  final double width;
  final bool prefersBelow;

  const _DropdownMenu({
    required this.value,
    required this.items,
    required this.iconBuilder,
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
          color: cardDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: primaryPurple.withAlpha(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (item) => _MenuItem(
                  item: item,
                  iconBuilder: iconBuilder,
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

    return Positioned(
      top: flippedTop,
      left: 0,
      child: menu,
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String item;
  final IconData Function(String) iconBuilder;
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.item,
    required this.iconBuilder,
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
            Icon(
              iconBuilder(item),
              color: isSelected ? highlightPurple : textSecondary,
              size: 16,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? textPrimary : textSecondary,
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
