import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/models/workout_log.dart';

final workoutHistoryProvider = FutureProvider.autoDispose
    .family<Map<String, List<WorkoutLog>>, DateTime>((ref, date) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final startOfDay = DateTime(date.year, date.month, date.day);
  final endOfDay = DateTime(date.year, date.month, date.day + 1);

  final startStr = startOfDay.toUtc().toIso8601String();
  final endStr = endOfDay.toUtc().toIso8601String();

  final results = await client
      .from('workout_logs')
      .select()
      .eq('member_id', userId)
      .gte('logged_at', startStr)
      .lt('logged_at', endStr)
      .order('logged_at', ascending: false);

  final logs = (results as List)
      .map((json) => WorkoutLog.fromJson(json as Map<String, dynamic>))
      .toList();

  final groups = <String, List<WorkoutLog>>{};
  for (final log in logs) {
    final name = log.workoutName ?? 'Workout';
    groups.putIfAbsent(name, () => []).add(log);
  }

  return groups;
});
