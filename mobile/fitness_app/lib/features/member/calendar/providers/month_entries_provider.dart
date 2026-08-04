import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

/// Month-scoped workout + meal log entries. Family is keyed by the first day
/// of the visible month; rebuilt when the month changes.
final monthEntriesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, DateTime>((ref, monthStart) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

  final results = await Future.wait([
    client
        .from('workout_logs')
        .select('exercise_name, logged_at, sets, reps, weight_kg, proof_url')
        .eq('member_id', userId)
        .gte('logged_at', monthStart.toUtc().toIso8601String())
        .lt('logged_at', monthEnd.toUtc().toIso8601String()),
    client
        .from('meal_logs')
        .select('food_name, meal_type, meal_time')
        .eq('member_id', userId)
        .gte('meal_time', monthStart.toUtc().toIso8601String())
        .lt('meal_time', monthEnd.toUtc().toIso8601String()),
  ]);

  return {
    'workouts': results[0] as List,
    'meals': results[1] as List,
  };
});