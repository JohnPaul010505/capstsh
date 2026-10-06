import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

/// Latest body measurement for the signed-in member, or null when none.
///
/// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
/// switch on the same device disposes the previous user's row.
final latestBodyMeasurementProvider =
    FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final client = SupabaseClientService().client;
  final userId = ref.watch(activeUserIdProvider);
  final authUid = client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }
  final rows = await client
      .from('body_measurements')
      .select('height_cm, weight_kg, measured_at')
      .eq('member_id', userId)
      .order('measured_at', ascending: false)
      .limit(1);
  if (rows.isEmpty) return null;
  return rows.first;
});
