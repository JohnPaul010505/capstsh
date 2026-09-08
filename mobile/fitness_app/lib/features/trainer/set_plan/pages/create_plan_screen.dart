// analyzer-workaround-20260907
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/widgets/app_glow_background.dart';

class CreatePlanScreen extends ConsumerStatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  ConsumerState<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends ConsumerState<CreatePlanScreen> {
  String? selectedClient;
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
      backgroundColor: const Color(0xFF0B0D1A),
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go('/trainer/dashboard');
                }
              },
              child: const Icon(CupertinoIcons.back, color: Color(0xFF7C3AED), size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Plan',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFFFFF),
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Assign a personalized plan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFA0A4B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: const Icon(CupertinoIcons.checkmark, color: Color(0xFF7C3AED), size: 20),
          ),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.person, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'CLIENT',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15172A),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: selectedClient,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 12),
              ),
              hint: const Text('Select Client *'),
              items: members.map((member) {
                return DropdownMenuItem<String>(
                  value: member['id'] as String?,
                  child: Text(
                    member['full_name'] as String? ?? '',
                    style: const TextStyle(color: Color(0xFFFFFFFF)),
                  ),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.flame, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'NUTRITION PLAN',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15172A),
            borderRadius: BorderRadius.circular(16),
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
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2035),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: widget.searchController,
                        style: const TextStyle(color: Color(0xFFFFFFFF)),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Search or enter food',
                          hintStyle: TextStyle(color: Color(0xFFA0A4B8)),
                        ),
                        onSubmitted: (_) => widget.onAddFood(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    color: const Color(0xFF7C3AED),
                    borderRadius: BorderRadius.circular(10),
                    onPressed: widget.onAddFood,
                    child: const Text('Add', style: TextStyle(color: Color(0xFFFFFFFF))),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.foods.isNotEmpty) ...[
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
                      color: const Color(0xFF1E2035),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            food['name'] ?? '',
                            style: const TextStyle(color: Color(0xFFFFFFFF)),
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: () => widget.onRemoveFood(index),
                          child: const Icon(CupertinoIcons.delete, color: Color(0xFFFF453A), size: 18),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.heart, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'TRAINING PLAN',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15172A),
            borderRadius: BorderRadius.circular(16),
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
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2035),
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.workoutType,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                    hint: const Text('Select workout type'),
                    items: widget.workoutTypes
                        .map((type) => DropdownMenuItem<String>(
                              value: type,
                              child: Text(type, style: const TextStyle(color: Color(0xFFFFFFFF))),
                            ))
                        .toList(),
                    onChanged: widget.onWorkoutTypeChanged,
                  ),
                ),
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
              ...widget.exercises.asMap().entries.map((entry) {
                final index = entry.key;
                final exercise = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2035),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exercise['name'] ?? '',
                              style: const TextStyle(
                                color: Color(0xFFFFFFFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${exercise['sets'] ?? 0} sets × ${exercise['reps'] ?? 0} reps${exercise['weight'] != null && exercise['weight'].toString().isNotEmpty ? ' • ${exercise['weight']} kg' : ''}',
                              style: const TextStyle(
                                color: Color(0xFFA0A4B8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CupertinoButton(
                        padding: const EdgeInsets.all(4),
                        onPressed: () => widget.onRemoveExercise(index),
                        child: const Icon(CupertinoIcons.delete, color: Color(0xFFFF453A), size: 18),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(80)),
                  borderRadius: BorderRadius.circular(12),
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
        backgroundColor: const Color(0xFF15172A),
        title: const Text('Add Exercise', style: TextStyle(color: Color(0xFFFFFFFF))),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: widget.nameController,
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                decoration: const InputDecoration(
                  labelText: 'Exercise Name',
                  labelStyle: TextStyle(color: Color(0xFFA0A4B8)),
                  filled: true,
                  fillColor: Color(0xFF1E2035),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.setsController,
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  labelStyle: TextStyle(color: Color(0xFFA0A4B8)),
                  filled: true,
                  fillColor: Color(0xFF1E2035),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.repsController,
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  labelStyle: TextStyle(color: Color(0xFFA0A4B8)),
                  filled: true,
                  fillColor: Color(0xFF1E2035),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: widget.weightController,
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  labelStyle: TextStyle(color: Color(0xFFA0A4B8)),
                  filled: true,
                  fillColor: Color(0xFF1E2035),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFFA0A4B8))),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onAddExercise();
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C3AED)),
            child: const Text('Add Exercise', style: TextStyle(color: Color(0xFFFFFFFF))),
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
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7C3AED).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(CupertinoIcons.doc_text, color: Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 12),
            Text(
              'NOTES',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFFFFFF),
                fontSize: 13,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF15172A),
            borderRadius: BorderRadius.circular(16),
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
                style: const TextStyle(color: Color(0xFFFFFFFF)),
                decoration: InputDecoration(
                  hintText: 'Add instructions, rest days, intensity, or trainer notes...',
                  hintStyle: const TextStyle(color: Color(0xFFA0A4B8)),
                  filled: true,
                  fillColor: const Color(0xFF1E2035),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(14),
      ),
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(14),
        onPressed: onPressed,
        child: isLoading
            ? const CupertinoActivityIndicator(color: Color(0xFFFFFFFF))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(CupertinoIcons.checkmark, color: Color(0xFFFFFFFF), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Assign Plan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
