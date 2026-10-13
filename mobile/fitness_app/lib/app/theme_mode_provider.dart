import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_tokens.dart';

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _restore();
  }

  static const _preferenceKey = 'fitness-app-theme-mode';

  Future<void> _restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(_preferenceKey);
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
      _preferenceKey,
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
