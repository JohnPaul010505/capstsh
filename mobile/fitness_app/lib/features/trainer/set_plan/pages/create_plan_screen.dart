// analyzer-workaround-20260907
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  String? selectedClient;
  String? selectedClientName;
  String? selectedWorkoutType;
  final TextEditingController notesController = TextEditingController();
  final TextEditingController foodSearchController = TextEditingController();
  final TextEditingController exerciseNameController = TextEditingController();
  final TextEditingController setsController = TextEditingController();
  final TextEditingController repsController = TextEditingController();
  final TextEditingController weightController = TextEditingController();

  List<Map<String, dynamic>> foods = [];
  List<Map<String, dynamic>> exercises = [];

  bool isSaving = false;
  List<Map<String, dynamic>>? members;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final client = SupabaseClientService().client;
    final response = await client
        .from('profiles')
        .select('id, full_name')
        .eq('role', 'member')
        .order('full_name', ascending: true);
    if (!mounted) return;
    setState(() {
      members = (response as List).cast<Map<String, dynamic>>();
      if (members != null && members!.isNotEmpty) {
        selectedClient = members!.first['id'] as String?;
        selectedClientName = members!.first['full_name'] as String?;
      }
    });
  }

  Future<void> _assignPlan() async {
    if (selectedClient == null) return;
    setState(() => isSaving = true);
    try {
      final client = SupabaseClientService().client;
      final planJson = <String, dynamic>{
        'member_id': selectedClient,
        'food_plan': foods.isNotEmpty ? foods : null,
        'exercise_plan': exercises.isNotEmpty ? exercises : null,
        'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'timeframe': '1_month',
        'updated_at': DateTime.now().toIso8601String(),
      };

      final trainerId = await client
          .from('profiles')
          .select('id')
          .eq('role', 'trainer')
          .single()
          .then((value) => value['id'] as String);

      planJson['trainer_id'] = trainerId;

      final existing = await client
          .from('member_goal_plans')
          .select('id')
          .eq('member_id', selectedClient!)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        await client
            .from('member_goal_plans')
            .update(planJson)
            .eq('member_id', selectedClient!);
      } else {
        planJson['created_at'] = DateTime.now().toIso8601String();
        await client.from('member_goal_plans').insert(planJson);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan assigned successfully')),
      );
      context.pop();
    } on Exception catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign plan: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _addFood() {
    if (foodSearchController.text.trim().isEmpty) return;
    setState(() {
      foods.add({
        'name': foodSearchController.text.trim(),
        'amount': '',
        'unit': '',
        'calories': '',
        'protein': '',
        'carbs': '',
        'fat': '',
      });
      foodSearchController.clear();
    });
  }

  void _removeFood(int index) {
    setState(() => foods.removeAt(index));
  }

  void _addExercise() {
    final name = exerciseNameController.text.trim();
    final sets = setsController.text.trim();
    final reps = repsController.text.trim();
    final weight = weightController.text.trim();
    if (name.isEmpty || sets.isEmpty || reps.isEmpty) return;

    setState(() {
      exercises.add({
        'name': name,
        'sets': sets,
        'reps': reps,
        'weight': weight,
      });
      exerciseNameController.clear();
      setsController.clear();
      repsController.clear();
      weightController.clear();
    });
  }

  void _removeExercise(int index) {
    setState(() => exercises.removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final membersList = members ??
        const [
          {'id': '', 'full_name': 'Loading members...'}
        ];

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    ClayCard(
                      variant: ClayCardVariant.outlined,
                      padding: ClayCardPadding.large,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClientSection(
                            members: membersList,
                            selectedClient: selectedClient,
                            onChanged: (value) {
                              setState(() => selectedClient = value);
                            },
                          ),
                          const SizedBox(height: 16),
                          _NutritionSection(
                            foods: foods,
                            searchController: foodSearchController,
                            onAddFood: _addFood,
                            onRemoveFood: _removeFood,
                          ),
                          const SizedBox(height: 16),
                          _TrainingSection(
                            exercises: exercises,
                            workoutType: selectedWorkoutType,
                            workoutTypes: const [
                              'Strength Training',
                              'Cardio',
                              'HIIT',
                              'Full Body',
                              'Upper Body',
                              'Lower Body',
                              'Push',
                              'Pull',
                              'Legs',
                              'Mobility',
                              'Custom',
                            ],
                            nameController: exerciseNameController,
                            setsController: setsController,
                            repsController: repsController,
                            weightController: weightController,
                            onWorkoutTypeChanged: (value) {
                              setState(() => selectedWorkoutType = value);
                            },
                            onAddExercise: _addExercise,
                            onRemoveExercise: _removeExercise,
                          ),
                          const SizedBox(height: 16),
                          _NotesSection(
                            controller: notesController,
                          ),
                          const SizedBox(height: 20),
                          _AssignPlanButton(
                            onPressed: isSaving ? null : _assignPlan,
                            isLoading: isSaving,
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.go('/trainer/profile'),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayPrimary,
            ),
          ),
          Expanded(
            child: Text(
              'Create Plan',
              textAlign: TextAlign.center,
              style: ClayTokens.darkHeadlineSmall.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _ClientSection extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final String? selectedClient;
  final ValueChanged<String?> onChanged;

  const _ClientSection({
    required this.members,
    required this.selectedClient,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CLIENT',
          style: ClayTokens.darkTitleSmall.copyWith(
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        DropdownField<String>(
          value: selectedClient,
          items: members.map((member) {
            final name = member['full_name'] as String? ?? '';
            final id = member['id'] as String? ?? '';
            return DropdownItem<String>(label: name, value: id);
          }).toList(),
          onChanged: onChanged,
          placeholder: 'Select Client',
        ),
      ],
    );
  }
}

class _NutritionSection extends StatefulWidget {
  final List<Map<String, dynamic>> foods;
  final TextEditingController searchController;
  final VoidCallback onAddFood;
  final ValueChanged<int> onRemoveFood;

  const _NutritionSection({
    required this.foods,
    required this.searchController,
    required this.onAddFood,
    required this.onRemoveFood,
  });

  @override
  State<_NutritionSection> createState() => _NutritionSectionState();
}

class _NutritionSectionState extends State<_NutritionSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NUTRITION PLAN',
          style: ClayTokens.darkTitleSmall.copyWith(
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurfaceElevated,
            borderRadius: BorderRadius.circular(ClayTokens.radiusLg),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Food Item',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: CupertinoTextField(
                      controller: widget.searchController,
                      placeholder: 'Search or enter food',
                      placeholderStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: ClayTokens.clayDarkBase,
                        borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                      ),
                      style: ClayTokens.darkBodyMedium,
                      cursorColor: ClayTokens.clayPrimary,
                      onSubmitted: (_) => widget.onAddFood(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                    onPressed: widget.onAddFood,
                    child: Text('Add', style: ClayTokens.darkBodyMedium.copyWith(color: Color(0xFFFFFFFF))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.foods.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkBase,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.add_circled, color: ClayTokens.clayPrimaryLight, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'No foods added yet',
                        style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                      ),
                    ],
                  ),
                )
              else ...[
                const Text(
                  'Added Foods',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.foods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final food = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: ClayTokens.clayDarkSurface,
                      borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            food['name'] ?? '',
                            style: ClayTokens.darkBodyMedium,
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: () => widget.onRemoveFood(index),
                          child: Icon(CupertinoIcons.delete, color: ClayTokens.clayError, size: 18),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TrainingSection extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;
  final String? workoutType;
  final List<String> workoutTypes;
  final TextEditingController nameController;
  final TextEditingController setsController;
  final TextEditingController repsController;
  final TextEditingController weightController;
  final ValueChanged<String?> onWorkoutTypeChanged;
  final VoidCallback onAddExercise;
  final ValueChanged<int> onRemoveExercise;

  const _TrainingSection({
    required this.exercises,
    required this.workoutType,
    required this.workoutTypes,
    required this.nameController,
    required this.setsController,
    required this.repsController,
    required this.weightController,
    required this.onWorkoutTypeChanged,
    required this.onAddExercise,
    required this.onRemoveExercise,
  });

  @override
  State<_TrainingSection> createState() => _TrainingSectionState();
}

class _TrainingSectionState extends State<_TrainingSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAINING PLAN',
          style: ClayTokens.darkTitleSmall.copyWith(
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurfaceElevated,
            borderRadius: BorderRadius.circular(ClayTokens.radiusLg),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workout Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              DropdownField<String>(
                value: widget.workoutType,
                items: widget.workoutTypes.map((type) {
                  return DropdownItem<String>(label: type, value: type);
                }).toList(),
                onChanged: widget.onWorkoutTypeChanged,
                placeholder: 'Select workout type',
              ),
              const SizedBox(height: 12),
              const Text(
                'Exercises',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.exercises.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkBase,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(CupertinoIcons.add_circled, color: ClayTokens.clayPrimaryLight, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'No exercises added yet',
                        style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                      ),
                    ],
                  ),
                )
              else
                ...widget.exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkSurface,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'] ?? '',
                              style: ClayTokens.darkBodyMedium.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exercise['sets'] ?? 0} sets × ${exercise['reps'] ?? 0} reps${exercise['weight'] != null && exercise['weight'].toString().isNotEmpty ? ' • ${exercise['weight']} kg' : ''}',
                              style: ClayTokens.darkBodySmall,
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => widget.onRemoveExercise(index),
                        child: Icon(CupertinoIcons.delete, color: ClayTokens.clayError, size: 18),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: ClayTokens.clayPrimary.withAlpha(128)),
                  borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                ),
                child: CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onPressed: () => _showAddExerciseDialog(context, widget),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(CupertinoIcons.plus, color: Color(0xFF7C3AED), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add Exercise',
                        style: TextStyle(color: Color(0xFF7C3AED)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAddExerciseDialog(BuildContext context, _TrainingSection widget) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ClayTokens.clayDarkCard,
        title: Text('Add Exercise', style: ClayTokens.darkHeadlineSmall),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.nameController,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  labelText: 'Exercise Name',
                  labelStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.setsController,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  labelText: 'Sets',
                  labelStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.repsController,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  labelText: 'Reps',
                  labelStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.weightController,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onAddExercise();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: ClayTokens.clayPrimary),
            child: Text('Add Exercise', style: ClayTokens.darkBodyMedium.copyWith(color: Color(0xFFFFFFFF))),
          ),
        ],
      ),
    );
  }
}

class _NotesSection extends StatelessWidget {
  final TextEditingController controller;

  const _NotesSection({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOTES',
          style: ClayTokens.darkTitleSmall.copyWith(
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurfaceElevated,
            borderRadius: BorderRadius.circular(ClayTokens.radiusLg),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 5,
                style: ClayTokens.darkBodyMedium,
                decoration: InputDecoration(
                  hintText: 'Add instructions, rest days, intensity, or trainer notes...',
                  hintStyle: ClayTokens.darkBodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssignPlanButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _AssignPlanButton({
    required this.onPressed,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
        ),
        borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
        onPressed: onPressed,
        child: isLoading
            ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
            : const Text(
                'Assign Plan',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFFFFFFF),
                ),
              ),
      ),
    );
  }
}

class DropdownItem<T> {
  final String label;
  final T value;
  const DropdownItem({required this.label, required this.value});
}

class DropdownField<T> extends StatefulWidget {
  final String? placeholder;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;

  const DropdownField({
    super.key,
    this.placeholder,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  State<DropdownField<T>> createState() => _DropdownFieldState<T>();
}

class _DropdownFieldState<T> extends State<DropdownField<T>> {
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
            child: _DropdownMenu<T>(
              value: widget.value,
              items: widget.items,
              onChanged: (value) {
                widget.onChanged(value);
                _close();
              },
              width: box.size.width,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    if (widget.value != null) {
      for (final item in widget.items) {
        if (item.value == widget.value) {
          selectedLabel = item.label;
          break;
        }
      }
    }

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: _openMenu,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkBase,
            borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
            border: Border.all(
              color: _open ? ClayTokens.clayPrimary.withAlpha(128) : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedLabel ?? widget.placeholder ?? 'Select...',
                  style: ClayTokens.darkBodyMedium.copyWith(
                    color: widget.value != null ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayDarkTextTertiary,
                  ),
                ),
              ),
              AnimatedRotation(
                turns: _open ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  CupertinoIcons.chevron_down,
                  color: ClayTokens.clayDarkTextTertiary,
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

class _DropdownMenu<T> extends StatelessWidget {
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?> onChanged;
  final double width;

  const _DropdownMenu({
    required this.value,
    required this.items,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkCard,
          borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
          border: Border.all(color: ClayTokens.clayPrimary.withAlpha(40)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: items
              .map(
                (item) => _MenuItem<T>(
                  item: item,
                  isSelected: item.value == value,
                  onTap: () => onChanged(item.value),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _MenuItem<T> extends StatelessWidget {
  final DropdownItem<T> item;
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
          color: isSelected ? ClayTokens.clayPrimary.withAlpha(25) : Colors.transparent,
          borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                item.label,
                style: ClayTokens.darkBodyMedium.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                CupertinoIcons.checkmark_circle_fill,
                color: ClayTokens.clayPrimaryLight,
                size: 18,
              ),
          ],
        ),
      ),
    );
  }
}
