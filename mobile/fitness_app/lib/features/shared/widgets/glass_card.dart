import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../app/design_tokens.dart';
import 'clay/clay_card.dart';

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
    final isLight = ClayColors.isLightMode;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? ClayTokens.clayPrimary.withAlpha(60)
              : ClayTokens.clayPrimary.withAlpha(40),
        ),
        boxShadow: [
          BoxShadow(
            color: ClayTokens.clayPrimary.withAlpha(isLight ? 30 : 18),
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
    final isLight = ClayColors.isLightMode;
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClayTokens.clayPrimaryLight.withAlpha(25),
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: Border.all(
          color: isLight
              ? ClayTokens.clayPrimary.withAlpha(55)
              : Colors.white.withAlpha(18),
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? ClayTokens.clayPrimary.withAlpha(28)
                : Colors.white.withAlpha(12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// Light-mode ink / surface helpers
// ---------------------------------------------------------------------------
// The glass bodies are near-white in light mode, so any text or fill that was
// hardcoded for a dark background has to flip. Every helper keeps the exact
// dark-mode value it is given, so switching these in changes LIGHT MODE ONLY.

/// Primary text ink for a liquid-glass body (dark ink in light mode).
Color glassInk([Color dark = const Color(0xFFFFFFFF)]) =>
    ClayColors.isLightMode ? ClayTokens.clayTextPrimary : dark;

/// Secondary text ink for a liquid-glass body.
Color glassInkDim([Color dark = const Color(0xFFB4B4D0)]) =>
    ClayColors.isLightMode ? ClayTokens.clayTextSecondary : dark;

/// Tertiary / label ink for a liquid-glass body.
Color glassInkFaint([Color dark = const Color(0xFF7070A0)]) =>
    ClayColors.isLightMode ? ClayTokens.clayTextTertiary : dark;

/// Fill for a glass container that is not wrapped in [GlassSurface].
Color glassFill([Color dark = const Color(0x12FFFFFF)]) =>
    ClayColors.isLightMode ? const Color(0xEBFFFFFF) : dark;

/// Body fill for a glass card that must keep its own container (no
/// [GlassSurface] wrapper) — e.g. one that carries a radial gradient.
Color glassBody([Color dark = const Color(0xFF1C1C2E)]) =>
    ClayColors.isLightMode ? const Color(0xF7F6F2FF) : dark;

/// Rarer, stronger glass fill (selected chips, preview panels).
Color glassFillStrong([Color dark = const Color(0x1FFFFFFF)]) =>
    ClayColors.isLightMode ? const Color(0xF7FFFFFF) : dark;

/// Hairline rim for a glass container.
Color glassRim([Color dark = const Color(0x2EFFFFFF)]) =>
    ClayColors.isLightMode ? ClayTokens.clayPrimary.withAlpha(70) : dark;

/// Hairline rim for a nested glass element (dimmer than [glassRim]).
Color glassRimSoft([Color dark = const Color(0x26FFFFFF)]) =>
    ClayColors.isLightMode ? ClayTokens.clayPrimary.withAlpha(45) : dark;

/// Label ink for text that sits on a PURPLE fill (chips, gradient buttons):
/// white in light mode and the near-white [ClayTokens.clayDarkTextPrimary]
/// (#ECECFC) dark mode already used — dark ink on the brand purple would be
/// the one unreadable pairing left in light mode.
Color get purpleLabel =>
    ClayColors.isLightMode ? const Color(0xFFFFFFFF) : ClayTokens.clayDarkTextPrimary;

/// Divider / track hairline inside a glass body.
Color glassLine([Color dark = const Color(0xFF2A2A45)]) =>
    ClayColors.isLightMode ? ClayTokens.clayDivider : dark;

/// Recessed panel behind inputs on a glass body.
Color glassPanel([Color dark = const Color(0xFF1C1C35)]) =>
    ClayColors.isLightMode ? const Color(0xFFEDE7FB) : dark;

/// The app's one liquid-glass recipe: translucent navy→indigo fill (white →
/// lilac in light mode), purple rim, purple glow and a lit top edge.
///
/// This is the member-home card surface (AI goal forecast / Active days), and
/// every other glass body now uses it too — the dashboard panels and the
/// member/trainer nav bars — so they all read as one material.
class GlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final double blur;
  final bool sheen;

  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(18)),
    this.blur = 18,
    this.sheen = true,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = ClayColors.isLightMode;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        // The glow lives outside the ClipRRect, otherwise the clip swallows it.
        boxShadow: [
          BoxShadow(
            color: isLight
                ? ClayTokens.clayPrimary.withAlpha(45)
                : const Color(0x2EBF5AF2),
            blurRadius: 18,
            spreadRadius: -6,
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
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isLight
                    ? const [Color(0xF2FFFFFF), Color(0xE6F0E6FF)]
                    : const [Color(0x8C1B1E41), Color(0x66140F2A)],
              ),
              border: Border.all(
                color: isLight
                    ? ClayTokens.clayPrimary.withAlpha(70)
                    : const Color(0x33BF5AF2),
              ),
            ),
            child: sheen
                ? Stack(
                    fit: StackFit.passthrough,
                    children: [
                      child,
                      Positioned(
                        top: 0,
                        left: 14,
                        right: 14,
                        child: IgnorePointer(
                          child: Container(
                            height: 1,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isLight
                                    ? [
                                        ClayTokens.clayPrimary.withAlpha(0),
                                        ClayTokens.clayPrimary.withAlpha(90),
                                        ClayTokens.clayPrimary.withAlpha(0),
                                      ]
                                    : const [
                                        Color(0x00FFFFFF),
                                        Color(0x59FFFFFF),
                                        Color(0x00FFFFFF),
                                      ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : child,
          ),
        ),
      ),
    );
  }
}

/// The member screens' card shell: the shared liquid-glass [GlassSurface] in
/// light mode, and the ORIGINAL dark-mode surface in dark mode — so light mode
/// reads as one glass material and dark mode is left untouched.
class MemberGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;

  /// Dark-mode fill for the default clay fallback.
  final Color? darkBackground;
  final bool animateEntrance;
  final Duration entranceDelay;

  /// Rebuilds the exact dark-mode surface for call sites that were not a plain
  /// translucent [ClayCard]. Defaults to that clay card.
  final Widget Function(Widget child)? darkBuilder;

  const MemberGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.darkBackground,
    this.animateEntrance = true,
    this.entranceDelay = Duration.zero,
    this.darkBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (ClayColors.isLightMode) {
      final glass = GlassSurface(
        margin: margin,
        padding: padding,
        borderRadius: borderRadius,
        child: child,
      );
      if (!animateEntrance) return glass;
      return glass
          .animate(delay: entranceDelay)
          .fadeIn(duration: ClayTokens.normal, curve: ClayTokens.easeOut)
          .slideY(
            begin: 0.1,
            end: 0,
            duration: ClayTokens.normal,
            curve: ClayTokens.easeOut,
          );
    }
    final builder = darkBuilder;
    if (builder != null) return builder(child);
    final card = ClayCard(
      variant: ClayCardVariant.outlined,
      backgroundColor:
          darkBackground ?? ClayTokens.clayPrimaryLight.withAlpha(25),
      customPadding: padding,
      padding: ClayCardPadding.none,
      borderRadius: borderRadius,
      animateEntrance: animateEntrance,
      entranceDelay: entranceDelay,
      child: child,
    );
    if (margin == null) return card;
    return Padding(padding: margin!, child: card);
  }
}

/// Backwards-compatible alias for [GlassSurface]: the dashboard, members,
/// progress and insight screens call this name, so it keeps working.
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
  Widget build(BuildContext context) => GlassSurface(
    padding: padding,
    margin: margin,
    borderRadius: borderRadius,
    blur: blur,
    child: child,
  );
}

/// Translucent bottom-sheet shell — the sheet twin of [GlassPanel]: a
/// top-rounded, backdrop-blurred dark-violet glass surface with a hairline
/// rim. Used by the trainer plan sheets and the trainer record details so
/// every sheet reads as one glass system.
class GlassSheetShell extends StatelessWidget {
  final Widget child;
  final double blur;
  final double fillOpacity;

  const GlassSheetShell({
    super.key,
    required this.child,
    this.blur = 28,
    this.fillOpacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = ClayColors.isLightMode;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? [
                      Color(0xFFF5F1FF).withValues(alpha: fillOpacity),
                      Color(0xFFECE4FF).withValues(alpha: fillOpacity),
                    ]
                  : [
                      Color(0xB31E1B3A).withValues(alpha: fillOpacity),
                      Color(0xD9120F26).withValues(alpha: fillOpacity),
                    ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(
              color: isLight
                  ? ClayTokens.clayPrimary.withAlpha(70)
                  : Colors.white.withAlpha(30),
            ),
            boxShadow: [
              BoxShadow(
                color: isLight
                    ? ClayTokens.clayPrimary.withAlpha(45)
                    : Colors.black.withAlpha(90),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
