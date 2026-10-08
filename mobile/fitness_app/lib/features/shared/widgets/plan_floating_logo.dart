import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/design_tokens.dart';
import '../providers/plan_providers.dart';

/// Member's floating trainer-plan logo — the bare logo image with NO
/// background circle (transparent around it).
/// - quick tap         -> onTap (opens the Day-1 sheet)
/// - single-finger drag -> move anywhere on screen (no long-press needed)
/// - two-finger pinch  -> resize (44-96 px)
/// Position/size persist across pages via [floatingLogoPositionProvider].
class PlanFloatingLogo extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final bool isExpanded;
  final String memberId;

  const PlanFloatingLogo({
    super.key,
    required this.onTap,
    required this.isExpanded,
    required this.memberId,
  });

  @override
  ConsumerState<PlanFloatingLogo> createState() => _PlanFloatingLogoState();
}

class _PlanFloatingLogoState extends ConsumerState<PlanFloatingLogo> {
  // Gesture state lives HERE (not in build): every drag tick calls
  // position.dragTo -> notifyListeners -> build reruns. Locals inside build()
  // would reset mid-drag and the logo would stick after one frame.
  Offset? _focalStart;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(floatingLogoPositionProvider);
    final size = position.size;

    // One GestureDetector using ONLY the scale recognizer. Flutter treats
    // onPan* + onScale* as conflicting recognizers and throws
    // ("scale is a superset of pan"), which red-screens release builds.
    // onScale* handles all three gestures here: one finger = drag,
    // two fingers = pinch-resize, no movement = tap (opens Day-1 sheet).
    // NOTE: onScaleEnd fires for taps too, so the tap check lives there —
    // there is intentionally no onTap callback.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (details) {
        _focalStart = details.focalPoint;
        _moved = false;
        if (details.pointerCount >= 2) {
          position.beginScale();
        } else {
          position.beginDrag(
              details.focalPoint, MediaQuery.sizeOf(context));
        }
      },
      onScaleUpdate: (details) {
        final start = _focalStart;
        if (start != null &&
            (details.focalPoint - start).distance > 8) {
          _moved = true;
        }
        if (details.pointerCount >= 2) {
          // Pinch with two fingers resizes; never treated as a tap.
          _moved = true;
          position.scaleTo(details.scale, MediaQuery.sizeOf(context));
        } else if (_moved) {
          position.dragTo(details.focalPoint, MediaQuery.sizeOf(context));
        }
      },
      onScaleEnd: (_) {
        position.persist();
        if (!_moved) widget.onTap();
        _focalStart = null;
      },
      child: AnimatedRotation(
        turns: widget.isExpanded ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        // Bare logo: no gradient circle, no ClipOval. logo.png carries its
        // own transparent margins — the purple disc in the screenshots was
        // the old BoxDecoration showing through them. A soft glow painted
        // BEHIND the image keeps depth without tinting transparent pixels.
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Soft radial glow BEHIND the image. A gradient circle fades to
            // transparent at its edges, so it never tints the logo's
            // transparent corners (a boxShadow blur would, which is what left
            // the purple disc in the screenshots).
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ClayTokens.clayPrimary.withAlpha(0),
                    ClayTokens.clayPrimary.withAlpha(90),
                  ],
                  stops: const [0.55, 1.0],
                ),
              ),
            ),
            Image.asset(
              'assets/logo.png',
              width: size,
              height: size,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: size * 0.46,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
