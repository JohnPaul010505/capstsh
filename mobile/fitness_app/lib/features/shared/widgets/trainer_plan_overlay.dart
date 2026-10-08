import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../trainer/set_plan/data/plan_repository.dart';
import '../../../../app/design_tokens.dart';
import 'glass_card.dart';
import 'trainer_notes_screen.dart';

/// Glass banner shown at the top of both plan sheets. Tapping it opens the
/// dedicated full-screen notes page; it never renders the whole note inline,
/// so a long one can't push the plan off-screen.
class _NotesBanner extends StatelessWidget {
  final String? notes;
  final VoidCallback onSeeAll;

  const _NotesBanner({required this.notes, required this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    final body = (notes ?? '').trim();
    if (body.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onSeeAll,
          borderRadius: BorderRadius.circular(14),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.sticky_note_2_outlined,
                    color: Color(0xFFD6A5FF), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Trainer notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFD6A5FF),
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: ClayTokens.clayDarkTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD6A5FF),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right,
                    color: Color(0xFFD6A5FF), size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

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
    final exercisePlan =
        (dayData['exercise_plan'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
    // The trainer writes plan rows GROUPED per day:
    //   exercise_plan = [{'day': 1, 'exercises': [{...}, {...}]}, ...]
    // so the day's exercises live one level down inside `exercises`. Reading
    // them flat returned the day wrapper itself, and the sheet rendered one
    // empty row instead of the trainer's recommendation.
    final dayExercises = _rowsForDay(exercisePlan, 'exercises');

    if (widget.dayNumber == 1) {
      await _autoCheckFromLogs(dayExercises);
      if (!mounted) return;
    }

    setState(() {
      exercises = dayExercises;
      _loading = false;
    });

    // Mirror the derived (log-matched) state back to the plan record so the
    // trainer's progress view reflects what the member actually did. Guarded:
    // only writes when something WAS auto-checked, so a day with no logs can
    // never wipe an earlier saved completion.
    if (widget.dayNumber == 1 && _completed.isNotEmpty) {
      await _syncCompletionFromLogs();
    }
  }

  /// Pulls the individual rows planned for [day] out of a per-day grouped
  /// plan column (`exercises` / `foods`). Tolerates a legacy FLAT shape
  /// (`[{'day':1,'name':…}, …]`) so plans written by older builds still show.
  List<Map<String, dynamic>> _rowsForDay(
    List<Map<String, dynamic>> planColumn,
    String nestedKey,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final group in planColumn) {
      if (group['day'] != widget.dayNumber) continue;
      final nested = group[nestedKey];
      if (nested is List) {
        rows.addAll(
          nested
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e)),
        );
      } else if ((group['name'] as String?)?.isNotEmpty == true) {
        // Legacy flat row: the entry IS the exercise/food itself.
        rows.add(Map<String, dynamic>.from(group));
      }
    }
    return rows;
  }

  /// Day-1 convenience: pre-check rows whose exercise name appears in the
  /// member's workout logs for today (case/whitespace-insensitive). Stores the
  /// ORIGINAL plan-row name so row UI comparisons keep working.
  Future<void> _autoCheckFromLogs(
    List<Map<String, dynamic>> dayExercises,
  ) async {
    try {
      final client = SupabaseClientService().client;
      final memberId = client.auth.currentUser?.id;
      if (memberId == null) return;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final rows =
          await client
              .from('workout_logs')
              .select('exercise_name')
              .eq('member_id', memberId)
              .gte(
                'created_at',
                startOfDay.toUtc().toIso8601String(),
              )
              .lt('created_at', endOfDay.toUtc().toIso8601String())
              .limit(200);
      final logged =
          (rows as List)
              .map(
                (r) => (r as Map)['exercise_name'] as String? ?? '',
              )
              .map(_norm)
              .where((n) => n.isNotEmpty)
              .toSet();
      if (logged.isEmpty) return;
      for (final e in dayExercises) {
        final name = e['name'] as String? ?? '';
        if (name.isNotEmpty && logged.contains(_norm(name))) {
          _completed.add(name);
        }
      }
    } catch (_) {
      // Auto-check is best-effort: rows just stay unchecked.
    }
  }

  String _norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Notes live on their own full screen (no nav bar) rather than inline in
  /// this sheet, so a long recommendation can't squeeze out the plan.
  void _openNotes(BuildContext context) {
    openTrainerNotesScreen(
      context,
      notes: widget.notes,
      dayLabel: 'Day ${widget.dayNumber} — Workout',
    );
  }

  /// Rows are READ-ONLY. A row shows as done only when the member actually
  /// performed it today (a matching `workout_logs` row), which
  /// [_autoCheckFromLogs] resolves on load. There is deliberately no
  /// tap-to-toggle: members cannot self-report completion, so the trainer's
  /// progress view only ever reflects real activity. This just mirrors that
  /// derived state back to the plan record.
  Future<void> _syncCompletionFromLogs() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await PlanRepository().saveDayCompletion(
        planId: widget.planId,
        memberId: SupabaseClientService().client.auth.currentUser!.id,
        dayNumber: widget.dayNumber,
        completedExercises: _completed.toList(),
        completedFoods: const [],
        isComplete:
            exercises.isNotEmpty && _completed.length == exercises.length,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
          // Centred title with the close button overlaid on the right, so the
          // heading sits on the true centre line of the sheet.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    'Day ${widget.dayNumber} — Trainer Plan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon:
                        const Icon(Icons.close, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF38383A), height: 1),
          _NotesBanner(
            notes: widget.notes,
            onSeeAll: () => _openNotes(context),
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
                          final isDone = _completed.contains(name);

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassPanel(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  // Read-only status dot: no GestureDetector,
                                  // so a tap can never change it.
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isDone
                                          ? const Color(0xFF30D158)
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isDone
                                            ? const Color(0xFF30D158)
                                            : const Color(0xFF8E8E93),
                                        width: 2,
                                      ),
                                    ),
                                    child: isDone
                                        ? const Icon(Icons.check,
                                            size: 14, color: Colors.white)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDone
                                                ? const Color(0xFF8E8E93)
                                                : const Color(0xFFFFFFFF),
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '$sets sets × $reps reps${weight.isNotEmpty ? ' • $weight kg' : ''}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDone
                                                ? const Color(0xFF636366)
                                                : const Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isDone)
                                    const Text(
                                      'Logged',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF30D158),
                                        letterSpacing: 0.4,
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
                '${_completed.length}/${exercises.length} logged today',
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
    final foodPlan = (dayData['food_plan'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // Same per-day grouping as exercises:
    //   food_plan = [{'day': 1, 'foods': [{...}, {...}]}, ...]
    // The day's foods live one level down inside `foods`.
    final dayFoods = _rowsForDay(foodPlan, 'foods');

    setState(() {
      foods = dayFoods;
      _loading = false;
    });
  }

  /// Pulls the individual rows planned for [day] out of a per-day grouped
  /// plan column (`foods`). Tolerates a legacy FLAT shape
  /// (`[{'day':1,'name':…}, …]`) so plans written by older builds still show.
  List<Map<String, dynamic>> _rowsForDay(
    List<Map<String, dynamic>> planColumn,
    String nestedKey,
  ) {
    final rows = <Map<String, dynamic>>[];
    for (final group in planColumn) {
      if (group['day'] != widget.dayNumber) continue;
      final nested = group[nestedKey];
      if (nested is List) {
        rows.addAll(
          nested
              .whereType<Map>()
              .map((f) => Map<String, dynamic>.from(f)),
        );
      } else if ((group['name'] as String?)?.isNotEmpty == true) {
        // Legacy flat row: the entry IS the food itself.
        rows.add(Map<String, dynamic>.from(group));
      }
    }
    return rows;
  }

  /// Notes live on their own full screen (no nav bar) rather than inline in
  /// this sheet, so a long recommendation can't squeeze out the plan.
  void _openNotes(BuildContext context) {
    openTrainerNotesScreen(
      context,
      notes: widget.notes,
      dayLabel: 'Day ${widget.dayNumber} — Nutrition',
    );
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
          // Centred title. The back arrow is gone: X is the single, obvious
          // way out of the sheet (a "<" next to an "X" made dismissal
          // ambiguous).
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    'Day ${widget.dayNumber} — Nutrition Plan',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFFFFFF),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close, color: Color(0xFF8E8E93)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF38383A), height: 1),
          _NotesBanner(
            notes: widget.notes,
            onSeeAll: () => _openNotes(context),
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

                                  return GlassPanel(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 12),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.restaurant_menu,
                                            size: 16,
                                            color: Color(0xFFD6A5FF)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFFFFFFF),
                                            ),
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