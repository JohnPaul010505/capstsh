import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

final latestBodyMeasurementProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final rows = await SupabaseClientService()
      .client
      .from('body_measurements')
      .select('height_cm, weight_kg, measured_at')
      .eq('member_id', userId)
      .order('measured_at', ascending: false)
      .limit(1);
  if (rows.isEmpty) return null;
  return rows.first;
});
