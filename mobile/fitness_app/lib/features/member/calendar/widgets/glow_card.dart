import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Dark card in the style of the "Explosive Growth" React component: near-black
/// surface with purple radial glows, a slowly rotating gradient border and a
/// soft top light. Wraps arbitrary [child] content.
class GlowCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final double borderWidth;

  const GlowCard({
    super.key,
    required this.child,
    this.borderRadius = 16,
    this.borderWidth = 2,
  });

  @override
  State<GlowCard> createState() => _GlowCardState();
}

class _GlowCardState extends State<GlowCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final angle = _controller.value * 2 * math.pi;
        return CustomPaint(
          foregroundPainter: _GlowBorderPainter(angle, widget.borderWidth, widget.borderRadius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFF0F0E16)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const _RadialGlow(const Color(0xFF5E3AEE), Alignment(-0.9, -0.9)),
                  const _RadialGlow(Color(0xFFC56BF0), Alignment(0.45, -0.6)),
                  const _RadialGlow(Color(0xFF7C3AED), Alignment(1.1, 0.9)),
                  _TopLight(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: widget.child,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Purple radial glow blob, transparent toward the edges.
class _RadialGlow extends StatelessWidget {
  final Color color;
  final Alignment center;

  const _RadialGlow(this.color, this.center);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: center,
              radius: 1.1,
              colors: [color.withAlpha(120), color.withAlpha(20), Colors.transparent],
              stops: const [0.0, 0.45, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft white top-light, mirroring the CSS inset box-shadow on .card.
class _TopLight extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white.withAlpha(36), Colors.transparent],
              stops: const [0.0, 0.22],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rotating conic-gradient border, equivalent of the CSS `rotate` sweep.
class _GlowBorderPainter extends CustomPainter {
  final double angle;
  final double width;
  final double radius;

  _GlowBorderPainter(this.angle, this.width, this.radius);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeJoin = StrokeJoin.round
      ..shader = SweepGradient(
        transform: GradientRotation(angle),
        colors: const [
          Color(0xFF7C3AED),
          Color(0xFFC56BF0),
          Color(0xFF4D1DDB),
          Color(0xFF2E1065),
          Color(0xFF7C3AED),
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter old) =>
      old.angle != angle || old.width != width || old.radius != radius;
}