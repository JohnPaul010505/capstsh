import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';
import 'glow_card.dart';

/// Light-mode-aware glow card: in light mode it renders a clay-surface-tinted
/// glass panel instead of the dark GlowCard, so the calendar card reads like the
/// rest of the light screens instead of carrying a dark-mode effect.
/// Dark mode always keeps the original [GlowCard] unchanged.
class LightAwareGlowCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;

  const LightAwareGlowCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (!ClayColors.isLightMode) {
      return GlowCard(
        borderRadius: borderRadius,
        borderWidth: borderWidth,
        child: child,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            color: ClayTokens.claySurfaceLight.withAlpha(245),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: ClayTokens.clayPrimary.withAlpha(45),
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: ClayTokens.clayPrimary.withAlpha(30),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}