import 'package:shared/services/supabase_client.dart';

class PlanRepository {
  final SupabaseClientService _supabase = SupabaseClientService();

  /// Active plan for a specific member/trainer pair. Scoping by both IDs
  /// prevents one trainer's plan from masking another's.
  Future<Map<String, dynamic>?> getActivePlan(
    String memberId,
    String trainerId, {
    bool includeTrainerProfile = false,
  }) async {
    try {
      final client = _supabase.client;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      // Active = today falls anywhere inside the plan window [start, end],
      // NOT just the start date. The old `start_date >= today` filter made
      // the plan "active" only on Day 1, which hid the floating logo for
      // days 2-7.
      final query = client
          .from('member_goal_plans')
          .select(includeTrainerProfile
              ? '*, profiles!member_goal_plans_trainer_id_fkey(full_name, avatar_url)'
              : '*')
          .eq('member_id', memberId)
          .eq('trainer_id', trainerId)
          .eq('status', 'active')
          .lte('start_date', today.split('T').first)
          .gte('end_date', today.split('T').first)
          .order('start_date', ascending: false)
          .limit(1);

      final response = await query.maybeSingle();

      if (response == null || response.isEmpty) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  /// All active plans for a member, joined with trainer profile details.
  /// Used by the member trainer-plan list and the displayed-plan selector.
  Future<List<Map<String, dynamic>>> getActivePlans(String memberId) async {
    try {
      final client = _supabase.client;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await client
          .from('member_goal_plans')
          .select(
            '*, profiles!member_goal_plans_trainer_id_fkey(full_name, avatar_url)',
          )
          .eq('member_id', memberId)
          .eq('status', 'active')
          .lte('start_date', today.split('T').first)
          .gte('end_date', today.split('T').first)
          .order('start_date', ascending: false);

      return (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Only the plans the member has chosen to display. Used by Workout and
  /// Food Intake to render the shared displayed-plan selector.
  Future<List<Map<String, dynamic>>> getDisplayedPlans(String memberId) async {
    try {
      final client = _supabase.client;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await client
          .from('member_goal_plans')
          .select(
            '*, profiles!member_goal_plans_trainer_id_fkey(full_name, avatar_url)',
          )
          .eq('member_id', memberId)
          .eq('status', 'active')
          .eq('is_displayed', true)
          .lte('start_date', today.split('T').first)
          .gte('end_date', today.split('T').first)
          .order('start_date', ascending: false);

      return (response as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> memberHasActivePlan(
    String memberId,
    String trainerId, {
    bool includeTrainerProfile = false,
  }) async {
    final plan = await getActivePlan(memberId, trainerId,
        includeTrainerProfile: includeTrainerProfile);
    return plan != null;
  }

  Future<void> assignPlan({
    required String memberId,
    required String trainerId,
    required List<Map<String, dynamic>> foodPlan,
    required List<Map<String, dynamic>> exercisePlan,
    String? notes,
  }) async {
    final client = _supabase.client;
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 6));

    final planData = <String, dynamic>{
      'member_id': memberId,
      'trainer_id': trainerId,
      'start_date': startDate.toIso8601String().split('T').first,
      'end_date': endDate.toIso8601String().split('T').first,
      'timeframe': '7_days',
      'status': 'active',
      'food_plan': foodPlan,
      'exercise_plan': exercisePlan,
      'updated_at': now.toIso8601String(),
    };

    if (notes != null && notes.trim().isNotEmpty) {
      planData['notes'] = notes.trim();
    }

    // Scope by member/trainer pair: each trainer gets their own plan row for
    // the member instead of overwriting another trainer's plan. Only the
    // CURRENT (active) row is replaced — cancelled history rows stay intact so
    // their completion records keep pointing at the plan they belong to.
    final existing = await client
        .from('member_goal_plans')
        .select('id')
        .eq('member_id', memberId)
        .eq('trainer_id', trainerId)
        .eq('status', 'active')
        .order('start_date', ascending: false)
        .limit(1)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      await client
          .from('member_goal_plans')
          .update(planData)
          .eq('id', existing['id'] as String);
    } else {
      planData['created_at'] = now.toIso8601String();
      await client.from('member_goal_plans').insert(planData);
    }
  }

  Future<List<Map<String, dynamic>>> getPlanDays(String planId) async {
    try {
      final response = await _supabase.client
          .from('member_goal_plans')
          .select('food_plan, exercise_plan')
          .eq('id', planId)
          .single();

      final foodPlan = (response['food_plan'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final exercisePlan = (response['exercise_plan'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();

      return [
        {'food_plan': foodPlan, 'exercise_plan': exercisePlan},
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> saveDayCompletion({
    required String planId,
    required String memberId,
    required int dayNumber,
    required List<String> completedExercises,
    required List<String> completedFoods,
    bool isComplete = false,
  }) async {
    final client = _supabase.client;
    final now = DateTime.now();
    final plan = await client
        .from('member_goal_plans')
        .select('start_date')
        .eq('id', planId)
        .single();

    final startDateStr = plan['start_date'] as String;
    final startDate = DateTime.parse(startDateStr);
    final date = DateTime(
      startDate.year,
      startDate.month,
      startDate.day + (dayNumber - 1),
    );

    final payload = <String, dynamic>{
      'plan_id': planId,
      'member_id': memberId,
      'day_number': dayNumber,
      'date': date.toIso8601String().split('T').first,
      'completed_exercises': completedExercises,
      'completed_foods': completedFoods,
      'is_complete': isComplete,
      'updated_at': now.toIso8601String(),
    };

    try {
      final existing = await client
          .from('plan_day_completions')
          .select('id, completed_exercises, completed_foods, is_complete')
          .eq('plan_id', planId)
          .eq('member_id', memberId)
          .eq('day_number', dayNumber)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
        // The workout sheet writes the EXERCISES half of this day row and
        // the food sheet writes the FOODS half — each save must MERGE with
        // what is already stored or it wipes the other sheet's work.
        // Completion is monotonic (rows derive from real logs), so unioning
        // the arrays and OR-ing is_complete is safe.
        final prevExercises =
            ((existing['completed_exercises'] as List?) ?? const [])
                .whereType<String>()
                .toSet();
        final prevFoods = ((existing['completed_foods'] as List?) ?? const [])
            .whereType<String>()
            .toSet();
        payload['completed_exercises'] = {
          ...prevExercises,
          ...completedExercises,
        }.toList();
        payload['completed_foods'] = {...prevFoods, ...completedFoods}.toList();
        payload['is_complete'] = existing['is_complete'] == true || isComplete;
        await client
            .from('plan_day_completions')
            .update(payload)
            .eq('id', existing['id'] as String);
      } else {
        payload['created_at'] = now.toIso8601String();
        await client.from('plan_day_completions').insert(payload);
      }
    } catch (_) {
      // silent fail for client-side operations
    }
  }

  Future<List<Map<String, dynamic>>> getMemberCompletions(
    String memberId,
  ) async {
    try {
      final response = await _supabase.client
          .from('plan_day_completions')
          .select()
          .eq('member_id', memberId)
          .order('day_number', ascending: true);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrainerPlanRecords(
    String trainerId,
  ) async {
    try {
      final plansResponse = await _supabase.client
          .from('member_goal_plans')
          .select(
            'id, member_id, start_date, end_date, food_plan, exercise_plan, notes, created_at, status, profiles!member_id(full_name)',
          )
          .eq('trainer_id', trainerId)
          .order('start_date', ascending: false);

      final plans = (plansResponse as List<dynamic>)
          .cast<Map<String, dynamic>>();

      final result = <Map<String, dynamic>>[];
      for (final plan in plans) {
        final completions = await _supabase.client
            .from('plan_day_completions')
            .select('day_number, completed_exercises, completed_foods')
            .eq('plan_id', plan['id'] as String)
            .order('day_number', ascending: true);
        final foodPlan = (plan['food_plan'] as List?) ?? const [];
        final exercisePlan = (plan['exercise_plan'] as List?) ?? const [];
        final totalDays = foodPlan.length > exercisePlan.length
            ? foodPlan.length
            : exercisePlan.length;
        final start = DateTime.tryParse(plan['start_date']?.toString() ?? '');
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final completedByDay = <int, Map>{
          for (final row in completions) (row['day_number'] as int): row,
        };
        var completedDays = 0;
        for (var day = 1; day <= totalDays; day++) {
          if (start == null ||
              DateTime(
                start.year,
                start.month,
                start.day,
              ).add(Duration(days: day - 1)).isAfter(today)) {
            continue;
          }
          final foodGroup = foodPlan
              .whereType<Map>()
              .cast<Map>()
              .where((g) => g['day'] == day)
              .firstOrNull;
          final exerciseGroup = exercisePlan
              .whereType<Map>()
              .cast<Map>()
              .where((g) => g['day'] == day)
              .firstOrNull;
          final plannedFoods = (foodGroup?['foods'] as List? ?? const [])
              .whereType<Map>()
              .toList();
          final plannedExercises =
              (exerciseGroup?['exercises'] as List? ?? const [])
                  .whereType<Map>()
                  .toList();
          final completion = completedByDay[day];
          if (completion == null ||
              plannedFoods.isEmpty ||
              plannedExercises.isEmpty) {
            continue;
          }
          final doneFoods =
              ((completion['completed_foods'] as List?) ?? const [])
                  .whereType<String>()
                  .toList();
          final doneExercises =
              ((completion['completed_exercises'] as List?) ?? const [])
                  .whereType<String>()
                  .toList();
          if (_allPlannedItemsDone(plannedFoods, doneFoods) &&
              _allPlannedItemsDone(plannedExercises, doneExercises)) {
            completedDays++;
          }
        }

        // Days count themselves: a plan day is "counted" once its calendar
        // day has arrived (start date = day 1), even when the member never
        // logged a sheet — so a 3-day plan shows 0/3 → 1/3 → 2/3 → 3/3 as
        // the dates pass, for active AND history (cancelled/completed)
        // plans alike. Real logged completions can only add on top, never
        // subtract, and nothing can pass the plan's total length.
        var countedDays = completedDays;
        if (start != null) {
          final startDay = DateTime(start.year, start.month, start.day);
          final elapsed = today.difference(startDay).inDays + 1;
          if (elapsed > countedDays) {
            countedDays = elapsed;
          }
        }
        if (countedDays > totalDays) countedDays = totalDays;
        if (countedDays < 0) countedDays = 0;

        result.add({
          'plan': plan,
          'completed_days': countedDays,
          'total_days': totalDays.clamp(1, 7),
          'completion_pct': countedDays / totalDays.clamp(1, 7),
          // The flip: "Complete" only when EVERY planned day's workouts AND
          // foods were really checked off — elapsed calendar days are not
          // completion, so a window that simply ran out stays Incomplete.
          'fully_completed': completedDays >= totalDays.clamp(1, 7),
        });
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  bool _allPlannedItemsDone(List<Map> planned, List<String> completed) {
    String normalize(String value) =>
        value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    final done = completed.map(normalize).toList();
    return planned.every((item) {
      final name = normalize(item['name']?.toString() ?? '');
      return name.isNotEmpty &&
          done.any(
            (entry) =>
                entry == name || entry.contains(name) || name.contains(entry),
          );
    });
  }

  /// Active plan for a specific member/trainer pair.
  Future<Map<String, dynamic>?> getPlanByMemberAndTrainer(
    String memberId,
    String trainerId,
  ) async {
    return await getActivePlan(memberId, trainerId);
  }

  /// Toggle the member-controlled display flag on one of their own plans via
  /// the Supabase `set_member_plan_displayed` RPC. The RPC enforces member
  /// ownership against `auth.uid()` and only touches `is_displayed`.
  Future<void> setPlanDisplayed(String planId, bool isDisplayed) async {
    final client = _supabase.client;
    await client.rpc(
      'set_member_plan_displayed',
      params: {'p_plan_id': planId, 'p_is_displayed': isDisplayed},
    );
  }

  Future<List<Map<String, dynamic>>> getPlanCompletionDays(
    String planId,
    String memberId,
  ) async {
    try {
      final response = await _supabase.client
          .from('plan_day_completions')
          .select()
          .eq('plan_id', planId)
          .eq('member_id', memberId)
          .order('day_number', ascending: true);

      return (response as List<dynamic>).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cancelPlan(String planId) async {
    await _supabase.client
        .from('member_goal_plans')
        .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', planId);
  }
}
