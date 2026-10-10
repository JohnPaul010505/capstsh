import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/profile.dart';
import '../services/auth_service.dart';
import '../services/supabase_client.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

// User-scoped cache buster: every user-dependent provider below watches this.
// On sign-out / account switch it changes (null -> profile / profile A ->
// profile B), which auto-disposes the old user's cached data instead of
// leaking e.g. a trainer's open attendance session into a member's Home.
final activeUserIdProvider = Provider<String?>((ref) {
  return ref.watch(authProvider).valueOrNull?.id;
});

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<Profile?>>((ref) {
  return AuthNotifier(ref.read(authServiceProvider));
});

class AuthNotifier extends StateNotifier<AsyncValue<Profile?>> {
  final AuthService _authService;
  StreamSubscription<AuthState>? _authSubscription;

  /// One live channel on the signed-in user's own `profiles` row. An admin
  /// editing this member in the panel (or a profile edit from a second device)
  /// re-fetches the row into [state], so every widget reading [authProvider] —
  /// the home greeting, the profile page, the trainer header — follows without
  /// a pull-to-refresh. The row's RLS allows the owner to read it, so no new
  /// policy is needed; migration 0041 is what puts `profiles` in the realtime
  /// publication. Before that migration is applied the subscription never
  /// fires and auth events (above) still carry sign-in — nothing breaks, the
  /// row is just stale until the next resume instead of live.
  RealtimeChannel? _profileChannel;
  String? _profileChannelUserId;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _init();
  }

  Future<void> _init() async {
    final client = SupabaseClientService().client;
    final currentUser = client.auth.currentUser;
    if (currentUser != null) {
      try {
        final profile = await _authService.refreshProfile();
        state = AsyncValue.data(profile);
        _watchOwnProfileRow(currentUser.id);
      } catch (e) {
        state = const AsyncValue.data(null);
      }
    } else {
      state = const AsyncValue.data(null);
    }

    _authSubscription = client.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      if (event == AuthChangeEvent.signedIn || event == AuthChangeEvent.tokenRefreshed) {
        final user = data.session?.user;
        if (user != null && state.valueOrNull?.id != user.id) {
          try {
            final profile = await _authService.refreshProfile();
            state = AsyncValue.data(profile);
            _watchOwnProfileRow(user.id);
          } catch (_) {}
        }
      } else if (event == AuthChangeEvent.signedOut) {
        _dropProfileChannel();
        state = const AsyncValue.data(null);
      }
    });
  }

  /// (Re)subscribes the live profile channel for [userId]; a no-op when it is
  /// already the subscribed user. Called after every successful sign-in and
  /// profile load so a sign-out -> sign-in-as-someone-else can never leave the
  /// previous user's row watched.
  void _watchOwnProfileRow(String userId) {
    if (_profileChannelUserId == userId) return;
    _dropProfileChannel();
    _profileChannelUserId = userId;
    final client = SupabaseClientService().client;
    _profileChannel = client.channel('own_profile_$userId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'profiles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: userId,
        ),
        callback: (_) => refreshProfile(),
      )
      ..subscribe();
  }

  void _dropProfileChannel() {
    final channel = _profileChannel;
    _profileChannel = null;
    _profileChannelUserId = null;
    if (channel != null) {
      SupabaseClientService().client.removeChannel(channel);
    }
  }

  @override
  void dispose() {
    _dropProfileChannel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final profile = await _authService.signIn(email: email, password: password);
      state = AsyncValue.data(profile);
      if (profile != null) _watchOwnProfileRow(profile.id);
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
      if (profile != null) _watchOwnProfileRow(profile.id);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  void setProfile(Profile? profile) {
    state = AsyncValue.data(profile);
    if (profile != null) {
      _watchOwnProfileRow(profile.id);
    } else {
      _dropProfileChannel();
    }
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
    _dropProfileChannel();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> completeOnboarding({
    required String gender,
    required double heightCm,
    required double weightKg,
    String? profileAsset,
  }) async {
    try {
      await _authService.completeOnboarding(
        gender: gender,
        heightCm: heightCm,
        weightKg: weightKg,
        profileAsset: profileAsset,
      );
      await refreshProfile();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateProfileAsset(String profileAsset) async {
    try {
      await _authService.updateProfileAsset(profileAsset);
      await refreshProfile();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phone,
    String? dateOfBirth,
    String? gender,
    String? avatarAsset,
  }) async {
    try {
      await _authService.updateProfile(
        fullName: fullName,
        email: email,
        phone: phone,
        dateOfBirth: dateOfBirth,
        gender: gender,
        avatarAsset: avatarAsset,
      );
      await refreshProfile();
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}
