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
  ///
  /// Throws when the row was not actually written — a silent RLS deny returns
  /// zero rows, and surfacing that beats showing a fake success.
  Future<void> rateTrainer({required String feedbackId, required int rating}) async {
    final updated = await _client.from('trainer_feedback').update({
      'rating': rating,
      'rated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', feedbackId).select('id');
    if ((updated as List).isEmpty) {
      throw Exception(
        'Rating was not saved — it may belong to another member or the session expired.',
      );
    }
  }

  /// The member's single comment on a piece of the trainer's feedback.
  ///
  /// Same write shape as [rateTrainer], and it needs no policy of its own: the
  /// "Members can rate own feedback" UPDATE policy from migration 0023 is scoped
  /// to `auth.uid() = member_id`, and the guard trigger widened in 0038 lets a
  /// member change the comment pair on their own rows while still refusing to
  /// let them rewrite the trainer's `content`.
  ///
  /// [comment] is trimmed by the caller and stored whole - there is one column,
  /// not a draft, so an edit overwrites the previous text rather than appending.
  ///
  /// Throws when the row was not actually written. Two silent-failure shapes
  /// are common here: the 0038 columns missing on the live database (PostgREST
  /// schema-cache / "column member_comment does not exist") and an RLS deny
  /// (zero rows returned). Both must reach the UI as the real message.
  Future<void> addMemberComment({required String feedbackId, required String comment}) async {
    try {
      final updated = await _client.from('trainer_feedback').update({
        'member_comment': comment,
        'member_commented_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', feedbackId).select('id');
      if ((updated as List).isEmpty) {
        throw Exception(
          'Comment was not saved — the feedback may belong to another member '
          'or the session expired. Pull to refresh and try again.',
        );
      }
    } on PostgrestException catch (e) {
      final msg = e.message;
      if (e.code == 'PGRST204' || msg.contains('member_comment')) {
        // Live database predates migration 0038: the member_comment columns
        // (and the widened guard trigger) do not exist there yet.
        throw Exception(
          'Comment was not saved — the database is missing the member_comment '
          'columns. Run supabase/migrations/0038_member_comment_on_feedback.sql '
          'in the Supabase SQL Editor, reload the schema cache, and try again.',
        );
      }
      if (msg.contains('Members may only update')) {
        throw Exception('Comment was not saved — $msg');
      }
      throw Exception('Could not save comment: $msg');
    }
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
