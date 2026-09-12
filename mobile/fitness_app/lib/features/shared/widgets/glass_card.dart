import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;

  const GlassCard({
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
