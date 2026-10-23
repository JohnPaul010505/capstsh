import '../utils/plan_meal_completion.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../trainer/set_plan/data/plan_repository.dart';
import '../../../../app/design_tokens.dart';
import '../providers/plan_providers.dart';
import '../utils/plan_day.dart';
import 'glass_card.dart';
import 'trainer_notes_screen.dart';

/// Lilac accent tuned for the dark sheets; on the light glass body it flips
/// to the brand purple so meal headers and note accents stay readable.
Color get _sheetAccent =>
    ClayColors.isLightMode ? ClayTokens.clayPrimary : const Color(0xFFD6A5FF);

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
                Icon(
                  Icons.sticky_note_2_outlined,
                  color: _sheetAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trainer notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _sheetAccent,
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
                Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _sheetAccent,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, color: _sheetAccent, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Trainer identity strip at the top of both plan sheets. With one displayed
/// plan it just names the trainer; with several it becomes the shared
/// Workout/Food Intake plan switcher, so changing it here changes the plan on
/// the other screen too.
class _TrainerPlanHeader extends StatelessWidget {
  final List<Map<String, dynamic>> plans;
  final String selectedPlanId;
  final Color accent;
  final String actionLabel;
  final ValueChanged<Map<String, dynamic>> onSelected;

  const _TrainerPlanHeader({
    required this.plans,
    required this.selectedPlanId,
    required this.accent,
    required this.actionLabel,
    required this.onSelected,
  });

  static String _trainerName(Map<String, dynamic> plan) {
    final profile = plan['profiles'];
    final name = profile is Map ? profile['full_name'] : null;
    final trimmed = (name ?? '').toString().trim();
    return trimmed.isEmpty ? 'Trainer' : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) return const SizedBox.shrink();
    final current = plans.firstWhere(
      (plan) => plan['id'] == selectedPlanId,
      orElse: () => plans.first,
    );
    final multi = plans.length > 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      child: GlassPanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.assignment_ind_outlined, size: 20, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Trainer plan',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _trainerName(current),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: glassInk(),
                    ),
                  ),
                ],
              ),
            ),
            if (multi)
              PopupMenuButton<String>(
                tooltip: 'Switch trainer plan',
                onSelected: (id) {
                  final plan = plans.firstWhere(
                    (candidate) => candidate['id'] == id,
                    orElse: () => current,
                  );
                  onSelected(plan);
                },
                itemBuilder: (_) => plans
                    .map(
                      (plan) => PopupMenuItem<String>(
                        value: plan['id'] as String,
                        child: Text(_trainerName(plan)),
                      ),
                    )
                    .toList(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Switch',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down, size: 18, color: accent),
                  ],
                ),
              )
            else
              Text(
                actionLabel,
                style: TextStyle(fontSize: 11, color: glassInkDim()),
              ),
          ],
        ),
      ),
    );
  }
}

/// Normalises a plan/log name for comparison: trimmed, lowercase, with
/// whitespace collapsed (shared by the workout and food sheets).
String _normPlanName(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// True when the member logged [name] today. Exact normalised match first,
/// then a containment match (both sides >= 4 chars) so a planned
/// "Bench Press" also hits a logged "Barbell Bench Press" and a planned
/// "Avocado, green" hits a logged "Avocado, green, raw".
bool _planNameLogged(String name, Set<String> logged) {
  final n = _normPlanName(name);
  if (n.isEmpty) return false;
  if (logged.contains(n)) return true;
  for (final l in logged) {
    if (l.length >= 4 && n.length >= 4 && (l.contains(n) || n.contains(l))) {
      return true;
    }
  }
  return false;
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
  ConsumerState<TrainerPlanWorkoutOverlay> createState() =>
      _TrainerPlanWorkoutOverlayState();
}

class _TrainerPlanWorkoutOverlayState
    extends ConsumerState<TrainerPlanWorkoutOverlay> {
  List<Map<String, dynamic>> exercises = [];
  final Set<String> _completed = <String>{};
  bool _loading = true;
  bool _saving = false;

  /// The plan this sheet currently shows. Starts from the caller's plan and
  /// changes when the member switches trainer plan here, so the shared
  /// selection (and the Food Intake sheet) follows along.
  late String _planId;
  late int _dayNumber;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _planId = widget.planId;
    _dayNumber = widget.dayNumber;
    _notes = widget.notes;
    _loadExercises();
  }

  /// Points the sheet at another displayed plan: that plan's active day is
  /// computed from its own window, then its rows are reloaded.
  Future<void> _switchTo(Map<String, dynamic> plan) async {
    final planId = plan['id'] as String?;
    if (planId == null || planId == _planId) return;
    setState(() {
      _planId = planId;
      _dayNumber = activePlanDay(
        startDate: plan['start_date'] as String?,
        totalDays: planDayCount(plan['exercise_plan']),
      );
      _notes = plan['notes'] as String?;
      exercises = [];
      _completed.clear();
      _loading = true;
    });
    await ref.read(selectedPlanIdProvider.notifier).select(planId);
    await _loadExercises();
  }

  Future<void> _loadExercises() async {
    final days = await PlanRepository().getPlanDays(_planId);
    if (!mounted) return;
    final dayData = days.isNotEmpty ? days.first : <String, dynamic>{};
    final exercisePlan = (dayData['exercise_plan'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // The trainer writes plan rows GROUPED per day:
    //   exercise_plan = [{'day': 1, 'exercises': [{...}, {...}]}, ...]
    // so the day's exercises live one level down inside `exercises`. Reading
    // them flat returned the day wrapper itself, and the sheet rendered one
    // empty row instead of the trainer's recommendation.
    final dayExercises = _rowsForDay(exercisePlan, 'exercises');

    // The sheet always opens on the member's CURRENT plan day (Day 1 on the
    // plan's start date, then Day 2 after 24 h, ...), so auto-checking and
    // mirroring today's logs applies to whichever day is active — not only
    // to Day 1.
    await _autoCheckFromLogs(dayExercises);
    if (!mounted) return;

    setState(() {
      exercises = dayExercises;
      _loading = false;
    });

    // Mirror the derived (log-matched) state back to the plan record so the
    // trainer's progress view reflects what the member actually did. Guarded:
    // only writes when something WAS auto-checked, so a day with no logs can
    // never wipe an earlier saved completion.
    if (_completed.isNotEmpty) {
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
      if (group['day'] != _dayNumber) continue;
      final nested = group[nestedKey];
      if (nested is List) {
        rows.addAll(
          nested.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
        );
      } else if ((group['name'] as String?)?.isNotEmpty == true) {
        // Legacy flat row: the entry IS the exercise/food itself.
        rows.add(Map<String, dynamic>.from(group));
      }
    }
    return rows;
  }

  /// Day-aware convenience: pre-check rows whose exercise name appears in the
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
      final rows = await client
          .from('workout_logs')
          .select('exercise_name')
          .eq('member_id', memberId)
          .gte('logged_at', startOfDay.toUtc().toIso8601String())
          .lt('logged_at', endOfDay.toUtc().toIso8601String())
          .limit(200);
      final logged = (rows as List)
          .map((r) => (r as Map)['exercise_name'] as String? ?? '')
          .map(_normPlanName)
          .where((n) => n.isNotEmpty)
          .toSet();
      if (logged.isEmpty) return;
      for (final e in dayExercises) {
        final name = e['name'] as String? ?? '';
        if (_planNameLogged(name, logged)) {
          _completed.add(name);
        }
      }
    } catch (_) {
      // Auto-check is best-effort: rows just stay unchecked.
    }
  }

  /// Notes live on their own full screen (no nav bar) rather than inline in
  /// this sheet, so a long recommendation can't squeeze out the plan.
  void _openNotes(BuildContext context) {
    openTrainerNotesScreen(
      context,
      notes: _notes,
      dayLabel: 'Day $_dayNumber — Workout',
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
        planId: _planId,
        memberId: SupabaseClientService().client.auth.currentUser!.id,
        dayNumber: _dayNumber,
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

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: GlassSheetShell(
        fillOpacity: 0.68,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ClayTokens.hairline.withAlpha(40),
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
                      'Day $_dayNumber — Trainer Plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: glassInk(),
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
            Divider(color: glassLine(const Color(0xFF38383A)), height: 1),
            _TrainerPlanHeader(
              plans: ref.watch(displayedPlansProvider).valueOrNull ?? const [],
              selectedPlanId: _planId,
              accent: _sheetAccent,
              actionLabel: 'Workout',
              onSelected: _switchTo,
            ),
            _NotesBanner(notes: _notes, onSeeAll: () => _openNotes(context)),
            Expanded(
              child: _loading
                  ? Center(
                      child: CupertinoActivityIndicator(color: _sheetAccent),
                    )
                  : exercises.isEmpty
                  ? const Center(
                      child: Text(
                        'No exercises planned for this day',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                              horizontal: 14,
                              vertical: 12,
                            ),
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
                                      ? Icon(
                                          Icons.check,
                                          size: 14,
                                          color: ClayTokens.clayDarkTextPrimary,
                                        )
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
                                              : glassInk(),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
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
  ConsumerState<TrainerPlanFoodOverlay> createState() =>
      _TrainerPlanFoodOverlayState();
}

class _TrainerPlanFoodOverlayState
    extends ConsumerState<TrainerPlanFoodOverlay> {
  List<Map<String, dynamic>> foods = [];
  final Set<String> _completed = <String>{};
  bool _loading = true;
  bool _saving = false;

  /// Same shared plan choice as the workout sheet: switching here updates the
  /// selected displayed plan for both screens.
  late String _planId;
  late int _dayNumber;
  String? _notes;

  @override
  void initState() {
    super.initState();
    _planId = widget.planId;
    _dayNumber = widget.dayNumber;
    _notes = widget.notes;
    _loadFoods();
  }

  Future<void> _switchTo(Map<String, dynamic> plan) async {
    final planId = plan['id'] as String?;
    if (planId == null || planId == _planId) return;
    setState(() {
      _planId = planId;
      _dayNumber = activePlanDay(
        startDate: plan['start_date'] as String?,
        totalDays: planDayCount(plan['food_plan']),
      );
      _notes = plan['notes'] as String?;
      foods = [];
      _completed.clear();
      _loading = true;
    });
    await ref.read(selectedPlanIdProvider.notifier).select(planId);
    await _loadFoods();
  }

  Future<void> _loadFoods() async {
    final days = await PlanRepository().getPlanDays(_planId);
    if (!mounted) return;
    final dayData = days.isNotEmpty ? days.first : <String, dynamic>{};
    final foodPlan = (dayData['food_plan'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    // Same per-day grouping as exercises:
    //   food_plan = [{'day': 1, 'foods': [{...}, {...}]}, ...]
    // The day's foods live one level down inside `foods`.
    final dayFoods = _rowsForDay(foodPlan, 'foods');

    // A food row shows as done the SAME way exercises do: the member
    // actually logged it today (a matching `meal_logs` row) — there is no
    // manual toggle, so the strike-through always reflects real intake.
    await _autoCheckFromLogs(dayFoods);
    if (!mounted) return;

    setState(() {
      foods = dayFoods;
      _loading = false;
    });

    if (_completed.isNotEmpty) {
      await _syncCompletion();
    }
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
      if (group['day'] != _dayNumber) continue;
      final nested = group[nestedKey];
      if (nested is List) {
        rows.addAll(
          nested.whereType<Map>().map((f) => Map<String, dynamic>.from(f)),
        );
      } else if ((group['name'] as String?)?.isNotEmpty == true) {
        // Legacy flat row: the entry IS the food itself.
        rows.add(Map<String, dynamic>.from(group));
      }
    }
    return rows;
  }

  /// Day-aware convenience, mirroring the workout sheet: pre-check rows whose
  /// food name appears in the member's meal logs for today
  /// (case/whitespace-insensitive, tolerant contains-match). Stores the
  /// ORIGINAL plan-row name so row UI comparisons keep working.
  Future<void> _autoCheckFromLogs(List<Map<String, dynamic>> dayFoods) async {
    try {
      final client = SupabaseClientService().client;
      final memberId = client.auth.currentUser?.id;
      if (memberId == null) return;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final rows = await client
          .from('meal_logs')
          .select('food_name, meal_type')
          .eq('member_id', memberId)
          .gte('meal_time', startOfDay.toUtc().toIso8601String())
          .lt('meal_time', endOfDay.toUtc().toIso8601String())
          .limit(200);
      final logged = (rows as List)
          .map(
            (r) => planMealKey(
              (r as Map)['food_name'] as String? ?? '',
              r['meal_type'] as String?,
            ),
          )
          .toSet();
      for (final food in dayFoods) {
        if (planMealLogged(food, logged)) {
          _completed.add(
            planMealKey(
              food['name'] as String? ?? '',
              food['meal_type'] as String?,
            ),
          );
        }
      }
    } catch (_) {
      // Auto-check is best-effort: rows just stay unchecked.
    }
  }

  /// Mirrors the derived (log-matched) food state back to the plan record so
  /// the trainer's progress view reflects what the member actually ate.
  /// `PlanRepository.saveDayCompletion` MERGES with the workout sheet's half
  /// of the day row, so this can never wipe exercise completion.
  Future<void> _syncCompletion() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await PlanRepository().saveDayCompletion(
        planId: _planId,
        memberId: SupabaseClientService().client.auth.currentUser!.id,
        dayNumber: _dayNumber,
        completedExercises: const [],
        completedFoods: _completed.toList(),
        isComplete: foods.isNotEmpty && _completed.length == foods.length,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Notes live on their own full screen (no nav bar) rather than inline in
  /// this sheet, so a long recommendation can't squeeze out the plan.
  void _openNotes(BuildContext context) {
    openTrainerNotesScreen(
      context,
      notes: _notes,
      dayLabel: 'Day $_dayNumber — Nutrition',
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
    mealTypes.keys
        .where((k) => !orderedMealTypes.contains(k))
        .forEach(orderedMealTypes.add);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: GlassSheetShell(
        fillOpacity: 0.68,
        child: Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: ClayTokens.hairline.withAlpha(40),
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
                      'Day $_dayNumber — Nutrition Plan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: glassInk(),
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
            Divider(color: glassLine(const Color(0xFF38383A)), height: 1),
            _TrainerPlanHeader(
              plans: ref.watch(displayedPlansProvider).valueOrNull ?? const [],
              selectedPlanId: _planId,
              accent: _sheetAccent,
              actionLabel: 'Nutrition',
              onSelected: _switchTo,
            ),
            _NotesBanner(notes: _notes, onSeeAll: () => _openNotes(context)),
            Expanded(
              child: _loading
                  ? Center(
                      child: CupertinoActivityIndicator(color: _sheetAccent),
                    )
                  : foods.isEmpty
                  ? const Center(
                      child: Text(
                        'No foods planned for this day',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
                                mealType[0].toUpperCase() +
                                    mealType.substring(1),
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _sheetAccent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...items.map((food) {
                                final name = food['name'] as String? ?? '';
                                final isDone = _completed.contains(
                                  planMealKey(
                                    name,
                                    food['meal_type'] as String?,
                                  ),
                                );

                                // Same treatment as the workout sheet: a
                                // done row gets the green check circle, a
                                // greyed strike-through name and the
                                // "Logged" badge.
                                return GlassPanel(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  child: Row(
                                    children: [
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
                                            ? Icon(
                                                Icons.check,
                                                size: 14,
                                                color: ClayTokens
                                                    .clayDarkTextPrimary,
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDone
                                                ? const Color(0xFF8E8E93)
                                                : glassInk(),
                                            decoration: isDone
                                                ? TextDecoration.lineThrough
                                                : TextDecoration.none,
                                          ),
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
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            if (foods.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding + 12),
                child: Text(
                  '${_completed.length}/${foods.length} logged today',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8E8E93),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            SizedBox(height: bottomPadding + 8),
          ],
        ),
      ),
    );
  }
}
