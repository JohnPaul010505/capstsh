import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

/// The member's currently running FOOD goal (daily calorie target), if any.
///
/// "Running" mirrors the workout Goals screen: status == 'active' and the
/// window has not passed its end date. A food goal's `target_value` is the
/// DAILY kcal target and `unit` is 'kcal/day'. Returns null when the member
/// has no running food goal so callers fall back to their default view.
///
/// Scoped to the signed-in member and `autoDispose`, so switching accounts
/// (member A light / member B dark, or member vs trainer) never leaks one
/// user's goal into another's screen.
final activeFoodGoalProvider = FutureProvider.autoDispose<Map<String, dynamic>?>(
  (ref) async {
    final client = SupabaseClientService().client;
    final activeUserId = ref.watch(activeUserIdProvider);
    final authUserId = client.auth.currentUser?.id;
    if (activeUserId == null ||
        activeUserId.isEmpty ||
        activeUserId != authUserId) {
      return null;
    }
    final rows = await client
        .from('goals')
        .select()
        .eq('member_id', activeUserId)
        .eq('status', 'active')
        .eq('goal_category', 'food')
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final goal = Map<String, dynamic>.from(rows.first as Map);
    final end = DateTime.tryParse(goal['end_date']?.toString() ?? '');
    // A missing end date counts as ongoing (safe side); a past end date does not.
    if (end != null && end.isBefore(DateTime.now())) return null;
    return goal;
  },
);

/// Total calories the member has logged for TODAY. Feeds the food goal card's
/// "consumed vs target" ring and the Food Intake screen's goal hint.
final todayCaloriesProvider = FutureProvider.autoDispose<int>((ref) async {
  final client = SupabaseClientService().client;
  final activeUserId = ref.watch(activeUserIdProvider);
  final authUserId = client.auth.currentUser?.id;
  if (activeUserId == null ||
      activeUserId.isEmpty ||
      activeUserId != authUserId) {
    return 0;
  }
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  final rows = await client
      .from('meal_logs')
      .select('calories')
      .eq('member_id', activeUserId)
      .gte('meal_time', startOfDay.toUtc().toIso8601String())
      .lt('meal_time', endOfDay.toUtc().toIso8601String());
  var total = 0;
  for (final r in (rows as List).cast<Map<String, dynamic>>()) {
    total += (r['calories'] as int? ?? 0);
  }
  return total;
});
