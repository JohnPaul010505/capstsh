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

  /// Feedback rows addressed to [memberId], with the trainer's name embedded
  /// (Figure 20: the Member views the feedback of the trainer).
  Future<List<Map<String, dynamic>>> getFeedbackWithTrainer(String memberId) async {
    final response = await _client
        .from('trainer_feedback')
        .select('*, trainer:profiles!trainer_feedback_trainer_id_fkey(full_name)')
        .eq('member_id', memberId)
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  /// Figure 20: the Member provides a star rating from one to five.
  Future<void> rateTrainer({required String feedbackId, required int rating}) async {
    await _client.from('trainer_feedback').update({
      'rating': rating,
      'rated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', feedbackId);
  }

  /// Average + count of the ratings a trainer has received.
  Future<Map<String, dynamic>> getRatingSummary(String trainerId) async {
    final rows = await _client
        .from('trainer_feedback')
        .select('rating')
        .eq('trainer_id', trainerId)
        .not('rating', 'is', null);
    final ratings = (rows as List)
        .map((r) => ((r as Map<String, dynamic>)['rating'] as num).toDouble())
        .toList();
    if (ratings.isEmpty) return {'average': 0.0, 'count': 0};
    final average = ratings.reduce((a, b) => a + b) / ratings.length;
    return {'average': average, 'count': ratings.length};
  }

  /// Feedback the trainer has already written (for the trainer profile page).
  Future<List<Map<String, dynamic>>> getGivenFeedback(String trainerId) async {
    final response = await _client
        .from('trainer_feedback')
        .select('*, member:profiles!trainer_feedback_member_id_fkey(full_name)')
        .eq('trainer_id', trainerId)
        .order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }
}
