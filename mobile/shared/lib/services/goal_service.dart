import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/goal.dart';
import 'supabase_client.dart';

class GoalService {
  final SupabaseClient _client;

  GoalService() : _client = SupabaseClientService().client;

  Future<List<Goal>> getGoals(String memberId) async {
    final response = await _client
        .from('goals')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<Goal> createGoal(Goal goal) async {
    final response = await _client
        .from('goals')
        .insert(goal.toJson())
        .select()
        .single();
    return Goal.fromJson(response);
  }

  Future<Goal> updateGoal(String id, Map<String, dynamic> updates) async {
    final response = await _client
        .from('goals')
        .update(updates)
        .eq('id', id)
        .select()
        .single();
    return Goal.fromJson(response);
  }
}
