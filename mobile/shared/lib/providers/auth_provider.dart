import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.signIn(email: email, password: password);
      state = AsyncValue.data(profile);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> signInWithCode(String code, String password) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.signInWithCode(
        code: code,
        password: password,
      );
      state = AsyncValue.data(profile);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void setProfile(Profile? profile) {
    state = AsyncValue.data(profile);
  }

  Future<void> refreshProfile() async {
    final current = state.valueOrNull;
    try {
      final profile = await _authService.refreshProfile();
      state = AsyncValue.data(profile ?? current);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }
}
