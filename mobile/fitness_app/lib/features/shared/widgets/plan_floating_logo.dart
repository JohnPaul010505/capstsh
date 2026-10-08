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
  Offset? _dragStart;
  bool _moved = false;

  @override
  Widget build(BuildContext context) {
    final position = ref.watch(floatingLogoPositionProvider);
    final size = position.size;

    // One GestureDetector: pan moves immediately (no long-press), scale with
    // two fingers resizes. A tap is a pan that barely moved — detected
    // manually from drag distance, because combining onTap with onPan* would
    // fire the sheet after every drag.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (details) {
        _dragStart = details.globalPosition;
        _moved = false;
        position.beginDrag(
            details.globalPosition, MediaQuery.sizeOf(context));
      },
      onPanUpdate: (details) {
        final start = _dragStart;
        if (start != null &&
            (details.globalPosition - start).distance > 8) {
          _moved = true;
        }
        if (_moved) {
          position.dragTo(details.globalPosition, MediaQuery.sizeOf(context));
        }
      },
      onPanEnd: (_) {
        position.persist();
        if (!_moved) widget.onTap();
        _dragStart = null;
      },
      onPanCancel: () => position.persist(),
      onScaleStart: (_) => position.beginScale(),
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          _moved = true; // a pinch is not a tap
          position.scaleTo(details.scale, MediaQuery.sizeOf(context));
        }
      },
      onScaleEnd: (_) => position.persist(),
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
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: ClayTokens.clayPrimary.withAlpha(70),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
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
