import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/design_tokens.dart';

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
  @override
  Widget build(BuildContext context) {
    return AnimatedRotation(
      turns: widget.isExpanded ? 1 : 0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 52,
          height: 52,
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
              width: 52,
              height: 52,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }
}