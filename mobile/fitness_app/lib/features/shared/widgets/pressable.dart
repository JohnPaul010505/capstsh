import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class PressableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? color;
  final BoxBorder? border;
  final List<BoxShadow>? shadows;
  final Decoration? decoration;

  const PressableCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.border,
    this.shadows,
    this.decoration,
  });

  @override
  State<PressableCard> createState() => _PressableCardState();
}

class _PressableCardState extends State<PressableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    setState(() => _pressed = true);
    _controller.forward();
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    if (!_pressed) return;
    setState(() => _pressed = false);
    _controller.reverse();
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    HapticFeedback.lightImpact();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, __) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: _handleTap,
            child: Opacity(
              opacity: _pressed ? 0.7 : 1.0,
              child: Container(
                padding: widget.padding,
                margin: widget.margin,
                decoration: widget.decoration ?? BoxDecoration(
                  color: widget.color ?? const Color(0xFF131320),
                  borderRadius: widget.borderRadius ?? BorderRadius.circular(16),
                  border: widget.border ?? Border.all(color: const Color(0xFF38383A).withAlpha(100)),
                  boxShadow: widget.shadows,
                ),
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final bool loading;
  final Color? color;
  final IconData? icon;
  final double? width;

  const GlowButton({
    super.key,
    required this.label,
    this.onTap,
    this.loading = false,
    this.color,
    this.icon,
    this.width,
  });

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const Color(0xFF0A84FF);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, __) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTapDown: widget.onTap == null ? null : (_) {
              if (!widget.loading) _controller.forward();
            },
            onTapUp: widget.onTap == null ? null : (_) => _controller.reverse(),
            onTapCancel: () => _controller.reverse(),
            onTap: widget.loading ? null : () {
              HapticFeedback.lightImpact();
              widget.onTap?.call();
            },
            child: Container(
              width: widget.width ?? double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, const Color(0xFF409CFF)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: color.withAlpha(50),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: widget.loading
                  ? const Center(child: CupertinoActivityIndicator(color: Color(0xFF0A84FF), radius: 10))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon, color: Colors.white, size: 16),
                          const SizedBox(width: 7),
                        ],
                        Text(widget.label, style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
                        )),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
