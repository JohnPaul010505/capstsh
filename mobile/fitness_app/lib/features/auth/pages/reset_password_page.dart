import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/auth_service.dart';
import '../../../app/cupertino_theme.dart';
import '../../shared/widgets/app_glow_background.dart';

class ResetPasswordPage extends ConsumerStatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  ConsumerState<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends ConsumerState<ResetPasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirm = false;
  String? _error;

  Future<void> _updatePassword() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters.');
      return;
    }
    if (password != _confirmController.text) {
      setState(() => _error = 'The passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.updatePassword(password);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        final message = error.toString().toLowerCase();
        _error = message.contains('expired') || message.contains('otp')
            ? 'This reset link expired or was already used. Request a new link.'
            : 'We could not update your password. Please try again.';
      });
      return;
    } finally {
      if (mounted) setState(() => _loading = false);
    }

    if (!mounted) return;
    // This page uses CupertinoPageScaffold, so a Material SnackBar is not a
    // reliable success signal. Keep the recovery session alive until the
    // member sees the confirmation and chooses to return to sign-in.
    await showCupertinoDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Password updated'),
        content: const Text(
          'Your password was changed successfully. Sign in with your new password.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Continue to sign in'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    try {
      await ref.read(authProvider.notifier).signOut();
    } catch (_) {
      // The password update already succeeded; still return to sign-in if
      // clearing the recovery session hits a transient network error.
    } finally {
      ref.read(passwordRecoveryModeProvider.notifier).state = false;
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoAppColors.background,
      child: Stack(
        children: [
          const Positioned.fill(
            child: IgnorePointer(
              child: AppGlowBackground(child: SizedBox.expand()),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                CupertinoNavigationBar(
                  backgroundColor: CupertinoAppColors.background.withValues(
                    alpha: 0.82,
                  ),
                  border: null,
                  middle: const Text('Create New Password'),
                  leading: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.go('/login'),
                    child: const Icon(CupertinoIcons.back),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: cardDecoration(
                              backgroundColor: const Color(0xB31B1835),
                              borderColor: CupertinoAppColors.purple.withValues(
                                alpha: 0.35,
                              ),
                              radius: 24,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Icon(
                                  CupertinoIcons.lock_shield,
                                  size: 62,
                                  color: CupertinoAppColors.purpleLight,
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Create a new password',
                                  textAlign: TextAlign.center,
                                  style: sfText(
                                    fontSize: 23,
                                    fontWeight: FontWeight.w700,
                                    color: CupertinoAppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Choose a new password with at least 8 characters.',
                                  textAlign: TextAlign.center,
                                  style: sfText(
                                    fontSize: 14,
                                    color: CupertinoAppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _passwordField(
                                  controller: _passwordController,
                                  placeholder: 'New password',
                                  visible: _showPassword,
                                  onToggle: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _passwordField(
                                  controller: _confirmController,
                                  placeholder: 'Confirm new password',
                                  visible: _showConfirm,
                                  onToggle: () => setState(
                                    () => _showConfirm = !_showConfirm,
                                  ),
                                  onSubmitted: (_) =>
                                      _loading ? null : _updatePassword(),
                                ),
                                if (_error != null) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    _error!,
                                    style: sfText(
                                      fontSize: 13,
                                      color: CupertinoAppColors.red,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 20),
                                CupertinoButton.filled(
                                  onPressed: _loading ? null : _updatePassword,
                                  borderRadius: BorderRadius.circular(14),
                                  child: _loading
                                      ? const CupertinoActivityIndicator(
                                          color: CupertinoAppColors.textPrimary,
                                        )
                                      : const Text('Update Password'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String placeholder,
    required bool visible,
    required VoidCallback onToggle,
    ValueChanged<String>? onSubmitted,
  }) => CupertinoTextField(
    controller: controller,
    obscureText: !visible,
    textInputAction: TextInputAction.done,
    autocorrect: false,
    enableSuggestions: false,
    placeholder: placeholder,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    style: sfText(fontSize: 15, color: CupertinoAppColors.textPrimary),
    placeholderStyle: sfText(
      fontSize: 14,
      color: CupertinoAppColors.textTertiary,
    ),
    decoration: BoxDecoration(
      color: CupertinoAppColors.cardElevated.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: CupertinoAppColors.separator),
    ),
    suffix: CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      onPressed: onToggle,
      child: Icon(
        visible ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
        color: CupertinoAppColors.textTertiary,
        size: 19,
      ),
    ),
    onSubmitted: onSubmitted,
  );
}
