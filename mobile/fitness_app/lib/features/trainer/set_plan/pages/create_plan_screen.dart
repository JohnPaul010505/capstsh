// analyzer-workaround-20260907
import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../data/plan_repository.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../../features/member/workout/data/met_exercise_repository.dart';

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

  int _currentDay = 1;
  String? _selectedMealType;
  final Map<int, List<Map<String, dynamic>>> foodsByDay = <int, List<Map<String, dynamic>>>{};
  final Map<int, List<Map<String, dynamic>>> exercisesByDay = <int, List<Map<String, dynamic>>>{};

  bool isSaving = false;
  List<Map<String, dynamic>>? members;
  Map<String, bool> memberHasActivePlan = <String, bool>{};
  bool _confirmReplace = false;

  bool _isDayComplete(int day) {
    final foods = foodsByDay[day] ?? [];
    final exercises = exercisesByDay[day] ?? [];
    return foods.length == 3 && exercises.isNotEmpty;
  }

  bool get _allDaysComplete {
    for (int day = 1; day <= 7; day++) {
      if (!_isDayComplete(day)) return false;
    }
    return true;
  }

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
    final membersList = (response as List).cast<Map<String, dynamic>>();

    final planChecks = <String, bool>{};
    for (final member in membersList) {
      final memberId = member['id'] as String? ?? '';
      if (memberId.isEmpty) continue;
      final hasPlan = await PlanRepository().memberHasActivePlan(memberId);
      planChecks[memberId] = hasPlan;
    }

    setState(() {
      members = membersList;
      memberHasActivePlan = planChecks;
      if (members != null && members!.isNotEmpty) {
        selectedClient = members!.first['id'] as String?;
        selectedClientName = members!.first['full_name'] as String?;
      }
    });
  }

  Future<void> _assignPlan() async {
    if (selectedClient == null) return;
    if (!_allDaysComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all 7 days before assigning.')),
      );
      return;
    }
    setState(() => isSaving = true);
    try {
      final client = SupabaseClientService().client;

      final foodPlan = List.generate(7, (day) {
        final dayNum = day + 1;
        return {
          'day': dayNum,
          'foods': foodsByDay[dayNum] ?? [],
        };
      });

      final exercisePlan = List.generate(7, (day) {
        final dayNum = day + 1;
        return {
          'day': dayNum,
          'exercises': exercisesByDay[dayNum] ?? [],
        };
      });

      final planJson = <String, dynamic>{
        'member_id': selectedClient,
        'food_plan': foodPlan,
        'exercise_plan': exercisePlan,
        'notes': notesController.text.trim().isNotEmpty ? notesController.text.trim() : null,
        'start_date': DateTime.now().toIso8601String().split('T').first,
        'end_date': DateTime.now().add(const Duration(days: 6)).toIso8601String().split('T').first,
        'timeframe': '7_days',
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
            .eq('id', existing['id'] as String);
      } else {
        planJson['created_at'] = DateTime.now().toIso8601String();
        await client.from('member_goal_plans').insert(planJson);
      }

      if (!mounted) return;
      final notes = notesController.text.trim();
      if (notes.isNotEmpty && selectedClient != null) {
        await NotificationService().createNotification(
          userId: selectedClient!,
          title: 'Trainer Set a Plan',
          body: notes,
        );
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
    if (_selectedMealType == null) return;
    if (foodSearchController.text.trim().isEmpty) return;
    final currentFoods = foodsByDay[_currentDay] ?? [];
    final addedTypes = currentFoods.map((f) => f['meal_type'] as String? ?? '').toSet();
    if (addedTypes.contains(_selectedMealType)) return;
    if (currentFoods.length >= 3) return;

    setState(() {
      foodsByDay.putIfAbsent(_currentDay, () => []).add({
        'name': foodSearchController.text.trim(),
        'meal_type': _selectedMealType,
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
    setState(() {
      final list = foodsByDay[_currentDay];
      if (list != null && index < list.length) {
        list.removeAt(index);
        _selectedMealType = null;
      }
    });
  }

  void _addExercise() {
    final name = exerciseNameController.text.trim();
    final sets = setsController.text.trim();
    final reps = repsController.text.trim();
    final weight = weightController.text.trim();
    if (name.isEmpty || sets.isEmpty || reps.isEmpty) return;

    setState(() {
      exercisesByDay.putIfAbsent(_currentDay, () => []).add({
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
    setState(() {
      final list = exercisesByDay[_currentDay];
      if (list != null && index < list.length) {
        list.removeAt(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersList = members ??
        const [
          {'id': '', 'full_name': 'Loading members...'}
        ];

    final currentFoods = foodsByDay[_currentDay] ?? <Map<String, dynamic>>[];
    final currentExercises = exercisesByDay[_currentDay] ?? <Map<String, dynamic>>[];
    final hasActivePlan = selectedClient != null && memberHasActivePlan[selectedClient!] == true;

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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: ClayTokens.clayPrimaryLight.withAlpha(25),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _ClientSection(
                            members: membersList,
                            selectedClient: selectedClient,
                            onChanged: (value) {
                              setState(() {
                                selectedClient = value;
                                _confirmReplace = false;
                              });
                            },
                          ),
                          if (hasActivePlan) ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF9500).withAlpha(20),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFFF9500).withAlpha(60)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF9500), size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This member already has an active plan. Creating a new plan will replace it.',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFFFCC02)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            if (!_confirmReplace)
                              CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  setState(() => _confirmReplace = true);
                                },
                                child: const Text(
                                  'I understand, continue',
                                  style: TextStyle(fontSize: 12, color: Color(0xFFD6A5FF)),
                                ),
                              ),
                          ] else ...[
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: ClayTokens.clayPrimaryLight.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withAlpha(18)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: ClayTokens.clayPrimaryLight, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'This member does not have an active plan yet.',
                                      style: const TextStyle(fontSize: 12, color: Color(0xFFFFFFFF)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _DaySelector(
                            currentDay: _currentDay,
                            isDayComplete: _isDayComplete,
                            onDayChanged: (day) {
                              setState(() => _currentDay = day);
                            },
                          ),
                          const SizedBox(height: 16),
                          _NutritionSection(
                            foods: currentFoods,
                            searchController: foodSearchController,
                            onAddFood: _addFood,
                            onRemoveFood: _removeFood,
                            selectedMealType: _selectedMealType,
                            onMealTypeChanged: (type) {
                              setState(() => _selectedMealType = type);
                            },
                          ),
                          const SizedBox(height: 16),
                          _TrainingSection(
                            day: _currentDay,
                            exercises: currentExercises,
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
              color: Colors.white,
            ),
          ),
          Expanded(
            child: Text(
              'CREATE PLAN',
              textAlign: TextAlign.center,
              style: ClayTokens.displaySmall.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

class _DaySelector extends StatelessWidget {
  final int currentDay;
  final ValueChanged<int> onDayChanged;
  final bool Function(int) isDayComplete;

  const _DaySelector({
    required this.currentDay,
    required this.onDayChanged,
    required this.isDayComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DAY',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: List.generate(7, (index) {
            final day = index + 1;
            final isSelected = day == currentDay;
            final complete = isDayComplete(day);
            Color backgroundColor;
            Color borderColor;
            Color textColor;

            if (complete && isSelected) {
              backgroundColor = const Color(0xFF7C3AED);
              borderColor = const Color(0xFF7C3AED);
              textColor = Colors.white;
            } else if (complete) {
              backgroundColor = const Color(0xFF7C3AED).withAlpha(120);
              borderColor = const Color(0xFF7C3AED).withAlpha(200);
              textColor = Colors.white;
            } else if (isSelected) {
              backgroundColor = ClayTokens.clayDarkSurfaceElevated;
              borderColor = ClayTokens.clayPrimary;
              textColor = ClayTokens.clayPrimary;
            } else {
              backgroundColor = ClayTokens.clayDarkSurfaceElevated;
              borderColor = Colors.white.withAlpha(18);
              textColor = ClayTokens.clayDarkTextSecondary;
            }

            return Expanded(
              child: GestureDetector(
                onTap: () => onDayChanged(day),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 36,
                  margin: EdgeInsets.only(right: index < 6 ? 6 : 0),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
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
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        DropdownField<String>(
          value: selectedClient,
          fillColor: ClayTokens.clayDarkSurfaceElevated,
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
  final String? selectedMealType;
  final ValueChanged<String?> onMealTypeChanged;

  const _NutritionSection({
    required this.foods,
    required this.searchController,
    required this.onAddFood,
    required this.onRemoveFood,
    required this.selectedMealType,
    required this.onMealTypeChanged,
  });

  @override
  State<_NutritionSection> createState() => _NutritionSectionState();
}

class _NutritionSectionState extends State<_NutritionSection> {
  static const _mealTypes = ['breakfast', 'lunch', 'dinner'];

  String _mealTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'breakfast':
        return 'Breakfast';
      case 'lunch':
        return 'Lunch';
      case 'dinner':
        return 'Dinner';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    final addedTypes = widget.foods.map((f) => f['meal_type'] as String? ?? '').toSet();
    final isFull = widget.foods.length >= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NUTRITION PLAN',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayPrimaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: _mealTypes.map((type) {
                  final isSelected = widget.selectedMealType == type;
                  final isAdded = addedTypes.contains(type);
                  return Expanded(
                    child: GestureDetector(
                      onTap: isAdded ? null : () => widget.onMealTypeChanged(type),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 36,
                        margin: EdgeInsets.only(right: type != _mealTypes.last ? 6 : 0),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? ClayTokens.clayPrimary
                                : isAdded
                                    ? ClayTokens.clayPrimary.withAlpha(40)
                                    : ClayTokens.clayDarkSurfaceElevated,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected
                                  ? ClayTokens.clayPrimary
                                  : isAdded
                                      ? ClayTokens.clayPrimary.withAlpha(120)
                                      : Colors.white.withAlpha(18),
                            ),
                          ),
                        child: Center(
                          child: Text(
                            _mealTypeLabel(type),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected || isAdded ? Colors.white : ClayTokens.clayDarkTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text(
                widget.selectedMealType != null
                    ? 'Add ${_mealTypeLabel(widget.selectedMealType!)}'
                    : 'Select a meal type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: widget.selectedMealType != null ? const Color(0xFFFFFFFF) : const Color(0xFF8E8E93),
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
                        color: ClayTokens.clayDarkSurfaceElevated,
                        borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                      ),
                      style: ClayTokens.darkBodyMedium,
                      cursorColor: ClayTokens.clayPrimary,
                      enabled: widget.selectedMealType != null && !isFull,
                      onSubmitted: (_) {
                        if (widget.selectedMealType != null && !isFull) {
                          widget.onAddFood();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                    onPressed: (widget.selectedMealType != null && !isFull) ? widget.onAddFood : null,
                    child: Text('Add', style: ClayTokens.darkBodyMedium.copyWith(color: Color(0xFFFFFFFF))),
                  ),
                ],
              ),
              if (isFull) ...[
                const SizedBox(height: 8),
                const Text(
                  'All meals added',
                  style: TextStyle(fontSize: 11, color: Color(0xFF30D158)),
                ),
              ],
              const SizedBox(height: 12),
              if (widget.foods.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkSurfaceElevated,
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
                    fontWeight: FontWeight.w400,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 8),
                ...widget.foods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final food = entry.value;
                  final mealType = food['meal_type'] as String? ?? '';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C3AED),
                      borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayPrimary.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: ClayTokens.clayPrimary.withAlpha(50)),
                          ),
                          child: Text(
                            _mealTypeLabel(mealType),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: ClayTokens.clayPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            food['name'] ?? '',
                            style: const TextStyle(color: Colors.white),
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
  final int day;
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
    required this.day,
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
  final TextEditingController _searchController = TextEditingController();
  final MetExerciseRepository _repository = MetExerciseRepository();
  Timer? _debounceTimer;
  List<MetExercise> _searchResults = [];
  bool _isSearching = false;
  String _query = '';
  bool _showAddButton = false;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_updateAddButtonVisibility);
    _updateAddButtonVisibility();
  }

  @override
  void didUpdateWidget(covariant _TrainingSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workoutType != widget.workoutType) {
      _updateAddButtonVisibility();
    }
  }

  void _updateAddButtonVisibility() {
    final show = widget.workoutType != null &&
        widget.nameController.text.trim().isNotEmpty;
    if (_showAddButton != show) {
      setState(() => _showAddButton = show);
    }
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_updateAddButtonVisibility);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(value);
    });
  }

  Future<void> _performSearch(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearching = true);

    try {
      final response = await _repository.search(q);
      if (mounted) {
        setState(() {
          _searchResults = response.matches;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _addExerciseFromSearch(MetExercise exercise) {
    widget.nameController.text = exercise.name;
    _searchController.clear();
    setState(() {
      _query = '';
      _searchResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  List<Widget> _buildExerciseItems() {
    if (widget.exercises.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurfaceElevated,
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
        ),
      ];
    }
    return widget.exercises.asMap().entries.map((entry) {
      final index = entry.key;
      final exercise = entry.value;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED),
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
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAINING PLAN',
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayPrimaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Workout Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              DropdownField<String>(
                value: widget.workoutType,
                fillColor: ClayTokens.clayDarkSurfaceElevated,
                items: widget.workoutTypes.map((type) {
                  return DropdownItem<String>(label: type, value: type);
                }).toList(),
                onChanged: widget.onWorkoutTypeChanged,
                placeholder: 'Select workout type',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                onChanged: _onQueryChanged,
                decoration: InputDecoration(
                  hintText: 'Search exercises…',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF7070A0), size: 18),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 8),
                const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD6A5FF)),
                  ),
                ),
              ],
              if (_searchResults.isEmpty && _query.isNotEmpty && !_isSearching) ...[
                const SizedBox(height: 8),
                const Text(
                  'No exercises found. Try a different search term.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
              ],
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Column(
                  children: _searchResults.map((e) {
                    return PressableCard(
                      onTap: () => _addExerciseFromSearch(e),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 6),
                      borderRadius: BorderRadius.circular(12),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: const Color(0xFFBF5AF2).withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Color(0xFFD6A5FF),
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.name,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                                ),
                                Text(
                                  '${e.category} · MET ${e.metValue.toStringAsFixed(1)}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: widget.nameController,
                decoration: InputDecoration(
                  hintText: 'Exercise name',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                  filled: true,
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.setsController,
                      decoration: InputDecoration(
                        hintText: 'Sets',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                        filled: true,
                        fillColor: ClayTokens.clayDarkSurfaceElevated,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.repsController,
                      decoration: InputDecoration(
                        hintText: 'Reps',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                        filled: true,
                        fillColor: ClayTokens.clayDarkSurfaceElevated,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: widget.weightController,
                      decoration: InputDecoration(
                        hintText: 'Weight (kg)',
                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF7070A0)),
                        filled: true,
                        fillColor: ClayTokens.clayDarkSurfaceElevated,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2A2A45)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFA78BFA)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFFFFFF)),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_showAddButton)
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
                  onPressed: () {
                    widget.onAddExercise();
                    setState(() => _showAddButton = false);
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(CupertinoIcons.plus, color: Color(0xFFFFFFFF), size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Add',
                        style: TextStyle(color: Color(0xFFFFFFFF)),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              const Text(
                'Exercises',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFFFFFFFF),
                ),
              ),
              const SizedBox(height: 8),
              ..._buildExerciseItems(),
            ],
          ),
        ),
      ],
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
          style: ClayTokens.displaySmall.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayPrimaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '(Optional)',
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
                  fillColor: ClayTokens.clayDarkSurfaceElevated,
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
  final Color? fillColor;

  const DropdownField({
    super.key,
    this.placeholder,
    required this.value,
    required this.items,
    required this.onChanged,
    this.fillColor,
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
            color: widget.fillColor ?? ClayTokens.clayDarkBase,
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
