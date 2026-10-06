import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

final monthEntriesProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, (String memberId, DateTime monthStart)>((
      ref,
      params,
    ) async {
      final memberId = params.$1;
      final monthStart = params.$2;
      final client = SupabaseClientService().client;
      // User-scoped: a trainer -> member switch on the same device must never
      // render the previous user's calendar rows as the new user's.
      final userId = ref.watch(activeUserIdProvider);
      final authUid = client.auth.currentUser?.id;
      if (userId == null || authUid == null || userId != authUid) {
        throw Exception('Signed out — please log in again.');
      }
      if (memberId != userId) {
        throw Exception('Signed out — please log in again.');
      }
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 1);

      final startUtc =
          DateTime(monthStart.year, monthStart.month, monthStart.day).toUtc();
      final endUtc = DateTime(monthEnd.year, monthEnd.month, monthEnd.day).toUtc();
      final startStr = startUtc.toIso8601String();
      final endStr = endUtc.toIso8601String();

      final results = await Future.wait([
        client
            .from('workout_logs')
            .select(
              'exercise_name, logged_at, sets, reps, weight_kg, proof_url, workout_name, total_calories, duration_seconds',
            )
            .eq('member_id', memberId)
            .gte('logged_at', startStr)
            .lt('logged_at', endStr),
        client
            .from('meal_logs')
            .select('food_name, meal_type, meal_time')
            .eq('member_id', memberId)
            .gte('meal_time', startStr)
            .lt('meal_time', endStr),
      ]);

      final workouts = results[0] as List;
      final meals = results[1] as List;

      return {
        'workouts': workouts,
        'meals': meals,
      };
    });
