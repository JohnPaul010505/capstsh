import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/providers/body_measurement_provider.dart';
import 'package:shared/services/supabase_client.dart';
import '../data/bmi_info.dart';

final latestBmiProvider = FutureProvider.autoDispose<BmiInfo?>((ref) async {
  final measurement = await ref.watch(latestBodyMeasurementProvider.future);
  if (measurement == null) return null;
  return bmiFromMeasurement(
    heightCm: measurement['height_cm'] as num?,
    weightKg: measurement['weight_kg'] as num?,
    measuredAt:
        DateTime.tryParse(measurement['measured_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );
});

/// Full BMI history for the current member, oldest first. Each point comes
/// from one `body_measurements` row (onboarding seeds the first one).
///
/// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
/// switch on the same device disposes the previous user's rows.
final bmiHistoryProvider = FutureProvider.autoDispose<List<BmiInfo>>((ref) async {
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
      .order('measured_at', ascending: true);
  final history = <BmiInfo>[];
  for (final row in rows) {
    final info = bmiFromMeasurement(
      heightCm: row['height_cm'] as num?,
      weightKg: row['weight_kg'] as num?,
      measuredAt:
          DateTime.tryParse(row['measured_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
    if (info != null) history.add(info);
  }
  return history;
});

/// Raw `body_measurements` rows for the current member, newest first. Used by
/// the BMI history list (date, weight, height, BMI, delete).
///
/// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
/// switch on the same device disposes the previous user's rows.
final bmiRawRowsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = ref.watch(activeUserIdProvider);
  final authUid = client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }
  final rows = await client
      .from('body_measurements')
      .select('id, height_cm, weight_kg, measured_at')
      .eq('member_id', userId)
      .order('measured_at', ascending: false);
  return (rows as List).cast<Map<String, dynamic>>();
});
