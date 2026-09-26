import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/auth_service.dart';
import '../../../app/cupertino_theme.dart';
import '../../shared/widgets/animations.dart';

/// Small helper: forces off any inherited text decoration (e.g. underline)
/// so labels always render clean regardless of ambient theme defaults.
TextStyle _clean(TextStyle style) =>
    style.copyWith(decoration: TextDecoration.none);

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  String? _error;
  bool _loading = false;
  bool _obscurePassword = true;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  // Drives the background glow rising toward the top while either
  // field is focused / being typed into.
  late AnimationController _bgController;
  late Animation<double> _bgAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _bgAnim = CurvedAnimation(
      parent: _bgController,
      curve: Curves.easeOutCubic,
    );

    _codeFocus.addListener(_handleFocusChange);
    _passwordFocus.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    final isTyping = _codeFocus.hasFocus || _passwordFocus.hasFocus;
    if (isTyping) {
      _bgController.forward();
    } else {
      _bgController.reverse();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _fadeController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;

    if (code.isEmpty) {
      setState(() => _error = 'Please enter your code');
      _fadeController.forward(from: 0);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'Please enter your password');
      _fadeController.forward(from: 0);
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final authService = AuthService();
      final profile = await authService.signInWithCode(
        code: code,
        password: password,
      );

      if (profile == null) {
        setState(() => _error = 'Invalid code or password');
        _fadeController.forward(from: 0);
        return;
      }

      if (!mounted) return;
      ref.read(authProvider.notifier).setProfile(profile);
      context.go(
        profile.role == 'trainer' ? '/trainer/dashboard' : '/member/home',
      );
    } catch (e) {
      setState(() => _error = e.toString());
      _fadeController.forward(from: 0);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      // Safety net: guarantees nothing in this subtree ever inherits an
      // underline from an ambient theme default.
      style: const TextStyle(decoration: TextDecoration.none),
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFF05091F),
        child: AnimatedBuilder(
          animation: _bgAnim,
          builder: (context, child) {
            final shift = _bgAnim.value * 60;
            return Stack(
              children: [
                // Admin atmosphere (admin/src/components/AppBackground.tsx):
                // rotated neon light trails + radial blooms, then the dark
                // vignette. IgnorePointer keeps taps for the form below.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Stack(
                      children: [
                        // Large purple trail — top left (-18°)
                        Positioned(
                          top: -170 - shift,
                          left: -230,
                          width: 560,
                          height: 280,
                          child: Transform.rotate(
                            angle: -0.31,
                            child: const _LightTrail(
                              colors: [
                                Color(0x6B8B5CF6),
                                Color(0x3D6366F1),
                                Color(0x008B5CF6),
                              ],
                              glow: [Color(0x8C8B5CF6), Color(0x528B5CF6)],
                            ),
                          ),
                        ),
                        // Blue trail — top right (+12°)
                        Positioned(
                          top: -130,
                          right: -240,
                          width: 520,
                          height: 260,
                          child: Transform.rotate(
                            angle: 0.21,
                            child: _LightTrail(
                              colors: [
                                Color(0x6B3B82F6),
                                Color(0x3D6366F1),
                                Color(0x003B82F6),
                              ],
                              glow: [Color(0x8C3B82F6), Color(0x523B82F6)],
                            ),
                          ),
                        ),
                        // Indigo sweep — centre (-8°)
                        Positioned(
                          top: 70,
                          left: -90,
                          width: 600,
                          height: 300,
                          child: Transform.rotate(
                            angle: -0.14,
                            child: _LightTrail(
                              colors: [
                                Color(0x426366F1),
                                Color(0x246366F1),
                                Color(0x006366F1),
                              ],
                              glow: [Color(0x596366F1), Color(0x336366F1)],
                            ),
                          ),
                        ),
                        // Purple sweep — bottom right (-15°)
                        Positioned(
                          bottom: -190 + shift,
                          right: -230,
                          width: 560,
                          height: 300,
                          child: Transform.rotate(
                            angle: -0.26,
                            child: const _LightTrail(
                              colors: [
                                Color(0x708B5CF6),
                                Color(0x3DA855F7),
                                Color(0x008B5CF6),
                              ],
                              glow: [Color(0x998B5CF6), Color(0x598B5CF6)],
                            ),
                          ),
                        ),
                        // Blue sweep — bottom left (+12°)
                        Positioned(
                          bottom: -150,
                          left: -240,
                          width: 520,
                          height: 280,
                          child: Transform.rotate(
                            angle: 0.21,
                            child: _LightTrail(
                              colors: [
                                Color(0x6B3B82F6),
                                Color(0x3D6366F1),
                                Color(0x003B82F6),
                              ],
                              glow: [Color(0x8C3B82F6), Color(0x523B82F6)],
                            ),
                          ),
                        ),
                        // Soft radial blooms behind the trails
                        const Positioned(
                          top: -150,
                          left: -140,
                          child: _GlowBlob(
                            size: 340,
                            colors: [
                              Color(0x578B5CF6),
                              Color(0x1E7C3AED),
                              Color(0x008B5CF6),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: 210,
                          left: -90,
                          child: _GlowBlob(
                            size: 280,
                            colors: [
                              Color(0x4D6366F1),
                              Color(0x146366F1),
                              Color(0x006366F1),
                            ],
                          ),
                        ),
                        const Positioned(
                          top: -120,
                          right: -130,
                          child: _GlowBlob(
                            size: 320,
                            colors: [
                              Color(0x573B82F6),
                              Color(0x1E3B82F6),
                              Color(0x003B82F6),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Dark vignette — mirrors the admin .theme-vignette.
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [Color(0x00020514), Color(0x8C020514)],
                        stops: [0.25, 1.0],
                      ),
                    ),
                  ),
                ),
                child!,
              ],
            );
          },
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 48),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Logo — sits fully above the glass card.
                            StaggeredFadeIn(
                              index: 0,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 132,
                                    height: 132,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0x408B5CF6),
                                          Color(0x1A7C3AED),
                                          Color(0x008B5CF6),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Image.asset(
                                    'assets/logo.png',
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Glass card
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 26,
                                  sigmaY: 26,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    30,
                                    24,
                                    26,
                                  ),
                                  decoration: BoxDecoration(
                                    // Liquid glass: the admin .glass-card
                                    // tint (rgba(25,30,65,0.52)) with a
                                    // purple wash toward the bottom and a
                                    // purple-tinted glass rim.
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0x8C191E41),
                                        Color(0x73191441),
                                        Color(0x8C241A4D),
                                      ],
                                      stops: [0.0, 0.55, 1.0],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Color(0x33BF5AF2),
                                    ),
                                    boxShadow: [
                                      // Purple ambient glow, same idea as
                                      // the admin login card's
                                      // 0 0 60px rgba(124,58,237,0.28).
                                      BoxShadow(
                                        color: Color(0x47BF5AF2),
                                        blurRadius: 52,
                                        spreadRadius: -8,
                                        offset: const Offset(0, 18),
                                      ),
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 44,
                                        offset: const Offset(0, 22),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Liquid-glass top highlight
                                      // (admin: inset 0 1px 0 rgba(255,255,255,0.11))
                                      Container(
                                        height: 1,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color(0x40FFFFFF),
                                              Color(0x00FFFFFF),
                                            ],
                                          ),
                                        ),
                                      ),
                                      StaggeredFadeIn(
                                        index: 1,
                                        child: ShaderMask(
                                          blendMode: BlendMode.srcIn,
                                          shaderCallback: (bounds) =>
                                              const LinearGradient(
                                                colors: [
                                                  CupertinoAppColors.purple,
                                                  CupertinoAppColors
                                                      .primaryBlue,
                                                ],
                                              ).createShader(bounds),
                                          child: Text(
                                            'FitTrack',
                                            textAlign: TextAlign.center,
                                            style: _clean(
                                              sfText(
                                                fontSize: 28,
                                                fontWeight: FontWeight.w800,
                                                color: CupertinoAppColors
                                                    .textPrimary,
                                                letterSpacing: 0.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      StaggeredFadeIn(
                                        index: 2,
                                        child: Text(
                                          'Your fitness journey starts here',
                                          textAlign: TextAlign.center,
                                          style: _clean(
                                            sfText(
                                              fontSize: 13,
                                              color: CupertinoAppColors
                                                  .textTertiary,
                                              letterSpacing: 0.1,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 26),
                                      StaggeredFadeIn(
                                        index: 3,
                                        child: Semantics(
                                          label: 'code input',
                                          child: _FloatingLabelInput(
                                            controller: _codeController,
                                            focusNode: _codeFocus,
                                            label: 'Member Code',
                                            textInputAction:
                                                TextInputAction.next,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      StaggeredFadeIn(
                                        index: 5,
                                        child: Semantics(
                                          label: 'password input',
                                          child: _FloatingLabelInput(
                                            controller: _passwordController,
                                            focusNode: _passwordFocus,
                                            label: 'Password',
                                            obscureText: _obscurePassword,
                                            textInputAction:
                                                TextInputAction.done,
                                            onSubmitted: (_) => _login(),
                                            suffix: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 2,
                                              ),
                                              child: GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () => setState(
                                                  () => _obscurePassword =
                                                      !_obscurePassword,
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    8,
                                                  ),
                                                  child: Icon(
                                                    _obscurePassword
                                                        ? CupertinoIcons
                                                              .eye_slash
                                                        : CupertinoIcons.eye,
                                                    color: CupertinoAppColors
                                                        .textTertiary,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_error != null) ...[
                                        const SizedBox(height: 14),
                                        AnimatedBuilder(
                                          animation: _fadeAnim,
                                          builder: (context, child) => Opacity(
                                            opacity: _fadeAnim.value,
                                            child: Transform.translate(
                                              offset: Offset(
                                                0,
                                                (1 - _fadeAnim.value) * -6,
                                              ),
                                              child: child,
                                            ),
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: CupertinoAppColors.red
                                                  .withValues(alpha: 0.12),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: CupertinoAppColors.red
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(
                                                  CupertinoIcons
                                                      .exclamationmark_circle,
                                                  color: CupertinoAppColors.red,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _error!,
                                                    style: _clean(
                                                      sfText(
                                                        color:
                                                            CupertinoAppColors
                                                                .red,
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 22),
                                      StaggeredFadeIn(
                                        index: 6,
                                        child: SizedBox(
                                          width: double.infinity,
                                          height: 52,
                                          child: CupertinoButton(
                                            onPressed: _loading ? null : _login,
                                            padding: EdgeInsets.zero,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              width: double.infinity,
                                              height: 52,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                gradient: const LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    CupertinoAppColors.purple,
                                                    CupertinoAppColors
                                                        .primaryBlue,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFFBF5AF2,
                                                    ).withValues(alpha: 0.45),
                                                    blurRadius: 18,
                                                    offset: const Offset(0, 10),
                                                  ),
                                                ],
                                              ),
                                              child: _loading
                                                  ? const CupertinoActivityIndicator(
                                                      color: CupertinoAppColors
                                                          .textPrimary,
                                                    )
                                                  : Text(
                                                      'Sign In',
                                                      style: _clean(
                                                        sfText(
                                                          fontSize: 17,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              CupertinoAppColors
                                                                  .textPrimary,
                                                          letterSpacing: 0.2,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        'v1.0.0 · Powered by FitTrack',
                                        textAlign: TextAlign.center,
                                        style: _clean(
                                          sfText(
                                            fontSize: 10,
                                            color:
                                                CupertinoAppColors.textTertiary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating label input field with animated label and border.
class _FloatingLabelInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final bool obscureText;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;
  final Widget? suffix;

  const _FloatingLabelInput({
    required this.controller,
    required this.focusNode,
    required this.label,
    this.obscureText = false,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.suffix,
  });

  @override
  State<_FloatingLabelInput> createState() => _FloatingLabelInputState();
}

class _FloatingLabelInputState extends State<_FloatingLabelInput> {
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    widget.focusNode.addListener(_onFocusChanged);
    _hasContent = widget.controller.text.isNotEmpty;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onChanged() {
    final hasContent = widget.controller.text.isNotEmpty;
    if (hasContent != _hasContent) {
      setState(() => _hasContent = hasContent);
    }
  }

  void _onFocusChanged() {
    setState(() {});
  }

  bool get _isFloating => widget.focusNode.hasFocus || _hasContent;

  @override
  Widget build(BuildContext context) {
    final floating = _isFloating;
    final focused = widget.focusNode.hasFocus;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: CupertinoAppColors.cardElevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: focused
              // Purple focus ring — the login card's accent colour.
              ? const Color(0xFFBF5AF2).withValues(alpha: 0.75)
              : CupertinoAppColors.separator.withValues(alpha: 0.4),
          width: focused ? 1.4 : 1,
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CupertinoTextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.obscureText,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: _clean(
              sfText(fontSize: 15, color: CupertinoAppColors.textPrimary),
            ),
            padding: const EdgeInsets.fromLTRB(16, 22, 16, 14),
            decoration: const BoxDecoration(),
            suffix: widget.suffix,
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            left: 16,
            top: floating ? -9 : 14,
            child: Container(
              color: CupertinoAppColors.cardElevated,
              padding: floating
                  ? const EdgeInsets.symmetric(horizontal: 4)
                  : EdgeInsets.zero,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                style: _clean(
                  sfText(
                    fontSize: floating ? 11 : 15,
                    color: focused
                        ? Colors.white
                        : CupertinoAppColors.textTertiary,
                  ),
                ),
                child: Text(widget.label),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One rotated neon "light trail" from the admin atmosphere
/// (admin/src/components/AppBackground.tsx): a soft pill gradient with a
/// two-layer coloured glow, the building block of the login background.
class _LightTrail extends StatelessWidget {
  final List<Color> colors;
  final List<Color> glow;

  const _LightTrail({required this.colors, required this.glow});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(400),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(color: glow[0], blurRadius: 70, spreadRadius: 8),
          BoxShadow(color: glow[1], blurRadius: 150, spreadRadius: 24),
        ],
      ),
    );
  }
}

/// Soft, non-interactive gradient glow used behind the login card for depth.
class _GlowBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
