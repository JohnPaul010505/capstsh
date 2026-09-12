import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../trainer/set_plan/data/plan_repository.dart';
import '../../../../app/design_tokens.dart';

class TrainerPlanWorkoutOverlay extends ConsumerStatefulWidget {
  final String planId;
  final int dayNumber;
  final String? notes;

  const TrainerPlanWorkoutOverlay({
    super.key,
    required this.planId,
    required this.dayNumber,
    this.notes,
  });

  @override
  ConsumerState<TrainerPlanWorkoutOverlay> createState() => _TrainerPlanWorkoutOverlayState();
}

class _TrainerPlanWorkoutOverlayState extends ConsumerState<TrainerPlanWorkoutOverlay> {
  List<Map<String, dynamic>> exercises = [];
  final Set<String> _completed = <String>{};
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final days = await PlanRepository().getPlanDays(widget.planId);
    if (!mounted) return;
    final dayData = days.isNotEmpty ? days.first : <String, dynamic>{};
    final exercisePlan = (dayData['exercise_plan'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final dayExercises = exercisePlan
        .where((e) => e['day'] == widget.dayNumber)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    setState(() {
      exercises = dayExercises;
      _loading = false;
    });
  }

  Future<void> _toggleExercise(String name) async {
    setState(() {
      if (_completed.contains(name)) {
        _completed.remove(name);
      } else {
        _completed.add(name);
      }
      _saving = true;
    });

    final repo = PlanRepository();
    final memberId = SupabaseClientService().client.auth.currentUser!.id;
    final exercisesJson = _completed.toList();
    final isComplete = exercises.isNotEmpty && _completed.length == exercises.length;

    await repo.saveDayCompletion(
      planId: widget.planId,
      memberId: memberId,
      dayNumber: widget.dayNumber,
      completedExercises: exercisesJson,
      completedFoods: const [],
      isComplete: isComplete,
    );

    if (mounted) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Day ${widget.dayNumber} — Trainer Plan',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF38383A), height: 1),
          if (widget.notes != null && widget.notes!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                widget.notes!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFD6A5FF),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)))
                : exercises.isEmpty
                    ? const Center(
                        child: Text(
                          'No exercises planned for this day',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: exercises.length,
                        itemBuilder: (context, index) {
                          final exercise = exercises[index];
                          final name = exercise['name'] as String? ?? '';
                          final sets = exercise['sets']?.toString() ?? '';
                          final reps = exercise['reps']?.toString() ?? '';
                          final weight = exercise['weight']?.toString() ?? '';
                          final isChecked = _completed.contains(name);

                          return GestureDetector(
                            onTap: _saving ? null : () => _toggleExercise(name),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: ClayTokens.clayDarkSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isChecked
                                      ? const Color(0xFF30D158).withAlpha(80)
                                      : const Color(0xFF38383A).withAlpha(100),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isChecked
                                          ? const Color(0xFF30D158)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isChecked
                                            ? const Color(0xFF30D158)
                                            : const Color(0xFF8E8E93),
                                        width: 2,
                                      ),
                                    ),
                                    child: isChecked
                                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isChecked
                                                ? const Color(0xFF8E8E93)
                                                : const Color(0xFFFFFFFF),
                                            decoration: isChecked
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$sets sets × $reps reps${weight.isNotEmpty ? ' • $weight kg' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isChecked
                                                ? const Color(0xFF636366)
                                                : const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          if (exercises.isNotEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 12),
              child: Text(
                '${_completed.length}/${exercises.length} completed',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class TrainerPlanFoodOverlay extends ConsumerStatefulWidget {
  final String planId;
  final int dayNumber;
  final String? notes;

  const TrainerPlanFoodOverlay({
    super.key,
    required this.planId,
    required this.dayNumber,
    this.notes,
  });

  @override
  ConsumerState<TrainerPlanFoodOverlay> createState() => _TrainerPlanFoodOverlayState();
}

class _TrainerPlanFoodOverlayState extends ConsumerState<TrainerPlanFoodOverlay> {
  List<Map<String, dynamic>> foods = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFoods();
  }

  Future<void> _loadFoods() async {
    final days = await PlanRepository().getPlanDays(widget.planId);
    if (!mounted) return;
    final dayData = days.isNotEmpty ? days.first : <String, dynamic>{};
    final foodPlan = (dayData['food_plan'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final dayFoods = foodPlan
        .where((f) => f['day'] == widget.dayNumber)
        .map((f) => Map<String, dynamic>.from(f))
        .toList();

    setState(() {
      foods = dayFoods;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final mealTypes = <String, List<Map<String, dynamic>>>{};

    for (final food in foods) {
      final mealType = (food['meal_type'] as String? ?? 'snack').toLowerCase();
      mealTypes.putIfAbsent(mealType, () => []).add(food);
    }

    final orderedMealTypes = <String>[];
    for (final type in ['breakfast', 'lunch', 'dinner', 'snack']) {
      if (mealTypes.containsKey(type)) {
        orderedMealTypes.add(type);
      }
    }
    mealTypes.keys.where((k) => !orderedMealTypes.contains(k)).forEach(orderedMealTypes.add);

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFFD6A5FF)),
                ),
                Expanded(
                  child: Text(
                    'Day ${widget.dayNumber} — Nutrition Plan',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF38383A), height: 1),
          if (widget.notes != null && widget.notes!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                widget.notes!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFFD6A5FF),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)))
                : foods.isEmpty
                    ? const Center(
                        child: Text(
                          'No foods planned for this day',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: orderedMealTypes.length,
                        itemBuilder: (context, index) {
                          final mealType = orderedMealTypes[index];
                          final items = mealTypes[mealType]!;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  mealType[0].toUpperCase() + mealType.substring(1),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFD6A5FF),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...items.map((food) {
                                  final name = food['name'] as String? ?? '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: ClayTokens.clayDarkSurface,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                               Text(
                                                 name,
                                                 style: const TextStyle(
                                                   fontSize: 14,
                                                   fontWeight: FontWeight.w600,
                                                   color: Color(0xFFFFFFFF),
                                                 ),
                                               ),
                                             ],
                                           ),
                                         ),
                                       ],
                                     ),
                                   );
                                }),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          SizedBox(height: bottomPadding + 8),
        ],
      ),
    );
  }
}