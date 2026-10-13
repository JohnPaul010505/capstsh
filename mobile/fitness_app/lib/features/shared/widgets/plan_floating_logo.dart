import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../providers/plan_providers.dart';
import 'glass_card.dart';

/// Member's floating trainer-plan logo — the bare logo image with NO
/// background shape at all (the earlier purple disc was a gradient/boxShadow
/// painted behind the PNG showing through its transparent margins).
///
/// Gestures, all on ONE scale recognizer (mixing `onPan*` with `onScale*`
/// makes Flutter throw "scale is a superset of pan" and red-screens):
///   - one finger, no movement -> tap (opens today's plan sheet)
///   - one finger, moved       -> drag, confined to [bounds] (the page's own
///                                body box, so it can never slip under the
///                                bottom nav bar)
///   - two fingers             -> pinch resize (44-96 px)
///
/// Releasing a drag in the middle of the screen snaps the logo to the nearer
/// side edge, so it never covers the page content.
class PlanFloatingLogo extends ConsumerStatefulWidget {
  final VoidCallback onTap;
  final bool isExpanded;
  final String memberId;

  /// The area the logo may occupy. Callers pass the page's body box (screen
  /// minus the nav bar) so the logo is always fully visible.
  final Size bounds;

  /// When true the logo gets the shared liquid-glass body in light mode. When
  /// false the logo is always bare (no background shape) in both modes — the
  /// mark with transparent margins shows straight through.
  final bool withGlass;

  const PlanFloatingLogo({
    super.key,
    required this.onTap,
    required this.isExpanded,
    required this.memberId,
    required this.bounds,
    this.withGlass = true,
  });

  @override
  ConsumerState<PlanFloatingLogo> createState() => _PlanFloatingLogoState();
}

Widget _logo(double size) {
  return Image.asset(
    'assets/logo.png',
    width: size,
    height: size,
    fit: BoxFit.contain,
    errorBuilder: (_, __, ___) => Icon(
      Icons.fitness_center,
      color: ClayTokens.clayDarkTextPrimary,
      size: size * 0.46,
    ),
  );
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
    final bounds = widget.bounds;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: (details) {
        _focalStart = details.focalPoint;
        _moved = false;
        if (details.pointerCount >= 2) {
          position.beginScale();
        } else {
          position.beginDrag(details.focalPoint, bounds);
        }
      },
      onScaleUpdate: (details) {
        final start = _focalStart;
        if (start != null && (details.focalPoint - start).distance > 8) {
          _moved = true;
        }
        if (details.pointerCount >= 2) {
          // Pinch with two fingers resizes; never treated as a tap.
          _moved = true;
          position.scaleTo(details.scale, bounds);
        } else if (_moved) {
          position.dragTo(details.focalPoint, bounds);
        }
      },
      onScaleEnd: (_) {
        // Release from the middle of the screen -> park it on a side edge.
        if (_moved) position.snapToSide(bounds);
        position.persist();
        // onScaleEnd also fires for taps, so the tap check lives here —
        // there is intentionally no onTap callback on this detector.
        if (!_moved) widget.onTap();
        _focalStart = null;
      },
      child: AnimatedRotation(
        turns: widget.isExpanded ? 1 : 0,
        duration: Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        // Dark mode keeps the bare logo: no circle, no gradient, no shadow
        // (logo.png has transparent margins, so a shape behind it shows straight
        // through). Light mode gives it the shared liquid-glass body so the mark
        // stays legible against the pale background. The disc + its padding add
        // up to exactly `size`, so the widget never grows past the footprint the
        // drag bounds and side-snapping were computed for.
        child: (ClayColors.isLightMode && widget.withGlass)
            ? GlassSurface(
                borderRadius: BorderRadius.circular(size / 2),
                padding: EdgeInsets.all(size * 0.12),
                child: _logo(size * 0.76),
              )
            : _logo(size),
      ),
    );
  }
}
