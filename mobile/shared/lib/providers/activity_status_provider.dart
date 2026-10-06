import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'auth_provider.dart';

final memberActivityStatusProvider = FutureProvider.autoDispose.family<bool, String>((ref, memberId) async {
  final client = SupabaseClientService().client;
  // User-scoped: after a trainer -> member switch on the same device, a stale
  // memberId must never render the previous user's attendance as this user's
  // fire. Mismatched ids read as inactive instead of leaking.
  final userId = ref.watch(activeUserIdProvider);
  final authUid = client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    return false;
  }
  if (memberId != userId) {
    return false;
  }
  // `check_in_date` is a plain date column — compare against a local
  // date-only string (a local datetime without a Z offset skews the
  // 7-day window by the UTC offset).
  final cutoff = DateTime.now().subtract(const Duration(days: 7));
  final sevenDaysAgo =
      '${cutoff.year.toString().padLeft(4, '0')}-'
      '${cutoff.month.toString().padLeft(2, '0')}-'
      '${cutoff.day.toString().padLeft(2, '0')}';
  final response = await client
      .from('attendance')
      .select('check_in_date')
      .eq('member_id', memberId)
      .gte('check_in_date', sevenDaysAgo)
      .limit(1);
  return (response as List).isNotEmpty;
});