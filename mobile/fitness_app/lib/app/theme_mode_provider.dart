import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared/providers/auth_provider.dart';

import 'design_tokens.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  // Rebuild whenever the signed-in account changes so every user gets their
  // OWN persisted light/dark choice back — switching accounts (or signing
  // out) can never leak one user's preference into another user's session.
  final userId = ref.watch(activeUserIdProvider);
  return ThemeModeNotifier(userId);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._userId) : super(ThemeMode.dark) {
    _restore();
  }

  final String? _userId;

  /// One preference per account: `<prefix>:<userId>` — or `:anonymous` while
  /// signed out — so member A's light mode and member B's dark mode coexist.
  static const _keyPrefix = 'fitness-app-theme-mode';

  /// Device-wide key from before per-user scoping. Migrated once into the
  /// first account that opens the app, then deleted so it can never leak
  /// across accounts again.
  static const _legacyKey = 'fitness-app-theme-mode';

  String get _key => '$_keyPrefix:${_userId ?? 'anonymous'}';

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      var saved = preferences.getString(_key);
      if (saved == null && _userId != null) {
        // One-time migration: adopt the old device-wide choice for this
        // account, then drop the global key.
        final legacy = preferences.getString(_legacyKey);
        if (legacy != null) {
          await preferences.setString(_key, legacy);
          await preferences.remove(_legacyKey);
          saved = legacy;
        }
      }
      final mode = saved == 'light' ? ThemeMode.light : ThemeMode.dark;
      if (mounted) _applyMode(mode);
    } catch (_) {
      // Keep the default dark appearance if the saved preference is unavailable.
    }
  }

  Future<void> toggle() =>
      setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);

  Future<void> setMode(ThemeMode mode) async {
    _applyMode(mode);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _key,
      mode == ThemeMode.light ? 'light' : 'dark',
    );
  }

  /// Single source of truth for the active brightness. Updating [state]
  /// rebuilds the UI, and pushing the same brightness into [ClayColors] keeps
  /// every static design token (text, glass, surfaces) in sync across the app.
  void _applyMode(ThemeMode mode) {
    ClayColors.setBrightness(
      mode == ThemeMode.light ? Brightness.light : Brightness.dark,
    );
    if (mounted) state = mode;
  }
}
