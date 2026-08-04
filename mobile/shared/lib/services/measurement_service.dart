import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/body_measurement.dart';
import 'supabase_client.dart';

class MeasurementService {
  final SupabaseClient _client;

  MeasurementService() : _client = SupabaseClientService().client;

  Future<List<BodyMeasurement>> getMeasurements(String memberId) async {
    final response = await _client
        .from('body_measurements')
        .select()
        .eq('member_id', memberId)
        .order('measured_at', ascending: true);
    return (response as List).map((e) => BodyMeasurement.fromJson(e)).toList();
  }

  Future<BodyMeasurement> createMeasurement(BodyMeasurement m) async {
    final response = await _client
        .from('body_measurements')
        .insert(m.toJson())
        .select()
        .single();
    return BodyMeasurement.fromJson(response);
  }
}
