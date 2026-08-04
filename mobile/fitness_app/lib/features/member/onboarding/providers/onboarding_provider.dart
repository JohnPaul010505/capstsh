import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';

/// A brand-new member needs onboarding when: role=member AND `profiles.gender`
/// is empty AND there are zero `body_measurements` rows. Non-members (trainer,
/// admin) and existing members always skip it.
///
/// The gate reads the DB directly (not the in-memory Profile) so invalidating
/// this provider after a successful save immediately flips it to false.
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

  /// Saves gender to `profiles` and the starting height/weight as one
  /// `body_measurements` row. RLS allows a member to update their own profile
  /// and insert their own measurement.
  static Future<void> complete({
    required String gender,
    required double heightCm,
    required double weightKg,
  }) async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser!.id;
    await client.from('profiles').update({'gender': gender}).eq('id', userId);
    await client.from('body_measurements').insert({
      'member_id': userId,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'measured_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
