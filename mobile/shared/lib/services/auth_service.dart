import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import 'supabase_client.dart';

class AuthService {
  final SupabaseClient _client;

  static const passwordRecoveryRedirect = 'triplejfitness://reset-password';

  AuthService() : _client = SupabaseClientService().client;

  Future<Profile?> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user == null) return null;
    return _fetchProfile(response.user!.id);
  }

  Future<Profile?> signInWithCode({
    required String code,
    required String password,
  }) async {
    String email;
    try {
      final result = await _client
          .from('profiles')
          .select('email')
          .eq('code', code.trim().toUpperCase())
          .maybeSingle();
      if (result == null || result.isEmpty) {
        throw Exception('Invalid member code');
      }
      email = result['email'] as String;
    } catch (e) {
      if (e is Exception && e.toString().contains('Invalid member code'))
        rethrow;
      throw Exception('Could not look up member code');
    }

    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (response.user == null) {
        throw Exception('Invalid credentials');
      }
      return await _fetchProfile(response.user!.id);
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('Invalid login credentials')) {
        throw Exception('Wrong password. Please try again.');
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) {
      throw Exception('Enter the email address on your account.');
    }
    await _client.auth.resetPasswordForEmail(
      normalizedEmail,
      redirectTo: passwordRecoveryRedirect,
    );
  }

  Future<void> updatePassword(String password) async {
    if (_client.auth.currentSession == null) {
      throw Exception('Your reset link expired. Request a new one.');
    }
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  Future<Profile?> refreshProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return _fetchProfile(user.id);
  }

  Future<Profile?> _fetchProfile(String userId) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();
    return Profile.fromJson(response);
  }

  Future<void> completeOnboarding({
    required String gender,
    required double heightCm,
    required double weightKg,
    String? profileAsset,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'gender': gender, 'avatar_url': profileAsset})
        .eq('id', user.id);
    await _client.from('body_measurements').insert({
      'member_id': user.id,
      'weight_kg': weightKg,
      'height_cm': heightCm,
      'measured_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> updateProfileAsset(String profileAsset) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    await _client
        .from('profiles')
        .update({'avatar_url': profileAsset})
        .eq('id', user.id);
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? avatarAsset,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final data = <String, dynamic>{
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'date_of_birth': dateOfBirth,
      'gender': gender,
    };
    if (avatarAsset != null) data['avatar_url'] = avatarAsset;
    await _client.from('profiles').update(data).eq('id', user.id);
  }

  Session? get currentSession => _client.auth.currentSession;
}
