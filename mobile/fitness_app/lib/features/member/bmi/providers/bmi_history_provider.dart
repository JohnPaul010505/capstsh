import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import '../data/bmi_info.dart';

/// Full BMI history for the current member, oldest first. Each point comes
/// from one `body_measurements` row (onboarding seeds the first one).
final bmiHistoryProvider = FutureProvider<List<BmiInfo>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final rows = await SupabaseClientService()
      .client
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
