import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/design_tokens.dart';
import '../providers/plan_providers.dart';

/// Member's floating trainer-plan logo.
/// - quick tap         -> onTap (opens the Day-1 sheet)
/// - long-press + drag -> move anywhere on screen
/// - two-finger pinch  -> resize (44-96 px)
/// Position/size persist across pages via [floatingLogoPositionProvider].
class PlanFloatingLogo extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(floatingLogoPositionProvider);
    final size = position.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (details) => position.beginDrag(
          details.globalPosition, MediaQuery.sizeOf(context)),
      onLongPressMoveUpdate: (details) => position.dragTo(
          details.globalPosition, MediaQuery.sizeOf(context)),
      onLongPressEnd: (_) => position.persist(),
      onScaleStart: (_) => position.beginScale(),
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          position.scaleTo(details.scale, MediaQuery.sizeOf(context));
        }
      },
      onScaleEnd: (_) => position.persist(),
      child: AnimatedRotation(
        turns: isExpanded ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [ClayTokens.clayPrimary, ClayTokens.clayPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ClayTokens.clayPrimary.withAlpha(100),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: size * 0.46,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
