import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

/// Month-scoped workout + meal log entries. Family is keyed by the first day
/// of the visible month; rebuilt when the month changes.
final monthEntriesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, DateTime>((ref, monthStart) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

  // Convert local calendar dates to UTC for correct timestamptz comparison.
  final startUtc = DateTime(monthStart.year, monthStart.month, monthStart.day).toUtc();
  final endUtc = DateTime(monthEnd.year, monthEnd.month, monthEnd.day).toUtc();
  final startStr = startUtc.toIso8601String();
  final endStr = endUtc.toIso8601String();

  final results = await Future.wait([
    client
        .from('workout_logs')
        .select('exercise_name, logged_at, sets, reps, weight_kg, proof_url')
        .eq('member_id', userId)
        .gte('logged_at', startStr)
        .lt('logged_at', endStr),
    client
        .from('meal_logs')
        .select('food_name, meal_type, meal_time')
        .eq('member_id', userId)
        .gte('meal_time', startStr)
        .lt('meal_time', endStr),
  ]);

  return {
    'workouts': results[0] as List,
    'meals': results[1] as List,
  };
});