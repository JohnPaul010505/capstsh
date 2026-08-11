import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

final needsOnboardingProvider = FutureProvider<bool>((ref) async {
  final profile = ref.watch(authProvider).valueOrNull;
  if (profile == null || profile.role != 'member') return false;

  final client = SupabaseClientService().client;
  final profileRow = await client
      .from('profiles')
      .select('gender')
      .eq('id', profile.id)
      .maybeSingle();
  final gender = profileRow?['gender'] as String?;
  if (gender != null && gender.trim().isNotEmpty) return false;

  final measurements = await client
      .from('body_measurements')
      .select('id')
      .eq('member_id', profile.id)
      .limit(1);
  return (measurements as List).isEmpty;
});

class OnboardingService {
  OnboardingService._();

  static Future<void> complete({
    required String gender,
    required double heightCm,
    required double weightKg,
    String? profileAsset,
  }) async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser!.id;
    await client.from('profiles').update({
      'gender': gender,
      'avatar_url': profileAsset,
    }).eq('id', userId);
    await client.from('body_measurements').insert({
      'member_id': userId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'measured_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
