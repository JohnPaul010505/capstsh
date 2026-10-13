import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show TextButton;
import 'package:go_router/go_router.dart';
import 'package:shared/services/auth_service.dart';
import '../../../app/cupertino_theme.dart';
import '../../shared/widgets/app_glow_background.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _sent = false;
  String? _error;

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      // Always show the same response so this screen cannot reveal whether an
      // email is registered in the app.
      setState(() => _sent = true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'We could not send the link right now. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
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
                  middle: const Text('Forgot Password'),
                  leading: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => context.pop(),
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
                            child: _sent
                                ? _buildSentContent(context)
                                : _buildForm(context),
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

  Widget _buildForm(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Icon(
        CupertinoIcons.lock_rotation,
        size: 62,
        color: CupertinoAppColors.purpleLight,
      ),
      const SizedBox(height: 18),
      Text(
        'Reset your password',
        textAlign: TextAlign.center,
        style: sfText(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: CupertinoAppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'Enter the email address connected to your member code. We will send you a secure reset link.',
        textAlign: TextAlign.center,
        style: sfText(fontSize: 14, color: CupertinoAppColors.textSecondary),
      ),
      const SizedBox(height: 24),
      CupertinoTextField(
        controller: _emailController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        autocorrect: false,
        placeholder: 'Registered email address',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 14),
          child: Icon(
            CupertinoIcons.mail,
            size: 18,
            color: CupertinoAppColors.purpleLight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
        onSubmitted: (_) => _loading ? null : _sendResetLink(),
      ),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: sfText(fontSize: 13, color: CupertinoAppColors.red),
        ),
      ],
      const SizedBox(height: 20),
      CupertinoButton(
        padding: const EdgeInsets.symmetric(vertical: 14),
        color: CupertinoAppColors.purple,
        borderRadius: BorderRadius.circular(14),
        onPressed: _loading ? null : _sendResetLink,
        child: _loading
            ? const CupertinoActivityIndicator(
                color: CupertinoAppColors.textPrimary,
              )
            : Text(
                'Send Reset Link',
                style: sfText(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: CupertinoAppColors.textPrimary,
                ),
              ),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () => context.go('/login'),
        child: Text(
          'Back to Sign In',
          style: sfText(fontSize: 14, color: CupertinoAppColors.purpleLight),
        ),
      ),
    ],
  );

  Widget _buildSentContent(BuildContext context) => Column(
    children: [
      const Icon(
        CupertinoIcons.envelope_badge,
        size: 64,
        color: CupertinoAppColors.purpleLight,
      ),
      const SizedBox(height: 18),
      Text(
        'Check your inbox',
        style: sfText(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: CupertinoAppColors.textPrimary,
        ),
      ),
      const SizedBox(height: 10),
      Text(
        'If an account is connected to that email, you will receive a password reset link. Check your spam folder too.',
        textAlign: TextAlign.center,
        style: sfText(fontSize: 14, color: CupertinoAppColors.textSecondary),
      ),
      const SizedBox(height: 22),
      CupertinoButton.filled(
        onPressed: () => context.go('/login'),
        child: const Text('Back to Sign In'),
      ),
    ],
  );
}
