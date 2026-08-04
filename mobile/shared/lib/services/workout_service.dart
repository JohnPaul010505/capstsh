import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_log.dart';
import 'supabase_client.dart';

class WorkoutService {
  final SupabaseClient _client;

  WorkoutService() : _client = SupabaseClientService().client;

  Future<List<WorkoutLog>> getWorkouts(String memberId) async {
    final response = await _client
        .from('workout_logs')
        .select()
        .eq('member_id', memberId)
        .order('logged_at', ascending: false);
    return (response as List).map((e) => WorkoutLog.fromJson(e)).toList();
  }

  Future<WorkoutLog> createWorkout(WorkoutLog log) async {
    final response = await _client
        .from('workout_logs')
        .insert(log.toJson())
        .select()
        .single();
    return WorkoutLog.fromJson(response);
  }

  Future<void> deleteWorkout(String id) async {
    await _client.from('workout_logs').delete().eq('id', id);
  }
}
