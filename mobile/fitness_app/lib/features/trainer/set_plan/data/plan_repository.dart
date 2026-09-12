import 'package:shared/services/supabase_client.dart';

class PlanRepository {
  final SupabaseClientService _supabase = SupabaseClientService();

  Future<Map<String, dynamic>?> getActivePlan(String memberId) async {
    try {
      final client = _supabase.client;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day).toIso8601String();

      final response = await client
          .from('member_goal_plans')
          .select()
          .eq('member_id', memberId)
          .gte('start_date', today.split('T').first)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null || response.isEmpty) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  Future<bool> memberHasActivePlan(String memberId) async {
    final plan = await getActivePlan(memberId);
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
      'food_plan': foodPlan,
      'exercise_plan': exercisePlan,
      'updated_at': now.toIso8601String(),
    };

    if (notes != null && notes.trim().isNotEmpty) {
      planData['notes'] = notes.trim();
    }

    final existing = await client
        .from('member_goal_plans')
        .select('id')
        .eq('member_id', memberId)
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

      return [{'food_plan': foodPlan, 'exercise_plan': exercisePlan}];
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
    final date = DateTime(startDate.year, startDate.month, startDate.day + (dayNumber - 1));

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
          .select('id')
          .eq('plan_id', planId)
          .eq('member_id', memberId)
          .eq('day_number', dayNumber)
          .maybeSingle();

      if (existing != null && existing['id'] != null) {
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

  Future<List<Map<String, dynamic>>> getMemberCompletions(String memberId) async {
    try {
      final response = await _supabase.client
          .from('plan_day_completions')
          .select()
          .eq('member_id', memberId)
          .order('day_number', ascending: true);

      return (response as List<dynamic>)
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrainerPlanRecords(String trainerId) async {
    try {
      final plansResponse = await _supabase.client
          .from('member_goal_plans')
          .select('id, member_id, start_date, end_date, notes, created_at, profiles(full_name)')
          .eq('trainer_id', trainerId)
          .order('start_date', ascending: false);

      final plans = (plansResponse as List<dynamic>).cast<Map<String, dynamic>>();

      final result = <Map<String, dynamic>>[];
      for (final plan in plans) {
        final completions = await _supabase.client
            .from('plan_day_completions')
            .select('day_number, is_complete')
            .eq('plan_id', plan['id'] as String)
            .order('day_number', ascending: true);

        final completedDays = (completions as List<dynamic>?)
                ?.where((c) => (c as Map)['is_complete'] == true)
                .length ??
            0;

        result.add({
          'plan': plan,
          'completed_days': completedDays,
          'total_days': 7,
          'completion_pct': completedDays / 7,
        });
      }

      return result;
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getPlanByMember(String memberId) async {
    try {
      final response = await _supabase.client
          .from('member_goal_plans')
          .select()
          .eq('member_id', memberId)
          .order('start_date', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null || response.isEmpty) return null;
      return Map<String, dynamic>.from(response as Map);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getPlanCompletionDays(String planId, String memberId) async {
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
}