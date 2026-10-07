import 'dart:ui';

import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';

/// Dark glass style card used on dashboard/posters (deep surface + dark border).
class GlassCardDark extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const GlassCardDark({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayPrimary.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: ClayTokens.clayPrimary.withAlpha(18),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Light glass style card matching the profile/feature-card look
/// (clayPrimaryLight.at(25) surface + white border at alpha 18).
class GlassCardLight extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const GlassCardLight({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClayTokens.clayPrimaryLight.withAlpha(25),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Liquid-glass panel — the exact recipe used by the trainer nav bar pill:
/// backdrop blur + white→purple translucent gradient + light rim + purple glow.
/// Used for the dashboard cards, the members search bar, the chat input, and
/// the dashboard screen-switcher menu so every surface reads as one glass system.
class GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;

  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.blur = 18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: ClayTokens.clayPrimary.withAlpha(41),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withAlpha(21),
                  ClayTokens.clayPrimaryLight.withAlpha(20),
                  ClayTokens.clayPrimary.withAlpha(24),
                ],
              ),
              borderRadius: borderRadius,
              border: Border.all(color: Colors.white.withAlpha(38)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
