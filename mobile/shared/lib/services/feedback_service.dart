import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/trainer_feedback.dart';
import 'supabase_client.dart';

class FeedbackService {
  final SupabaseClient _client;

  FeedbackService() : _client = SupabaseClientService().client;

  Future<List<TrainerFeedback>> getFeedbackForMember(String memberId) async {
    final response = await _client
        .from('trainer_feedback')
        .select()
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (response as List).map((e) => TrainerFeedback.fromJson(e)).toList();
  }

  Future<TrainerFeedback> submitFeedback(TrainerFeedback feedback) async {
    final response = await _client
        .from('trainer_feedback')
        .insert(feedback.toJson())
        .select()
        .single();
    return TrainerFeedback.fromJson(response);
  }
}
