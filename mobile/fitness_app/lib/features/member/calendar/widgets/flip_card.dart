import 'dart:math' as math;
import 'package:flutter/material.dart';

/// 3D flip card: front and back faces share the same bounds; toggling
/// [flipped] rotates them around the Y axis (front faces away at 90°).
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool flipped;
  final Duration duration;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.flipped,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
      value: widget.flipped ? 1 : 0,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(covariant FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.flipped != widget.flipped) {
      if (widget.flipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final halfPi = math.pi / 2;
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final angle = _animation.value * math.pi;
        final frontVisible = angle <= halfPi;
        final frontTransform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle);
        final backTransform = Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateY(angle - math.pi);
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform(
              alignment: Alignment.center,
              transform: frontTransform,
              child: Visibility(
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                visible: frontVisible,
                child: IgnorePointer(ignoring: !frontVisible, child: widget.front),
              ),
            ),
            Transform(
              alignment: Alignment.center,
              transform: backTransform,
              child: Visibility(
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                visible: !frontVisible,
                child: IgnorePointer(ignoring: frontVisible, child: widget.back),
              ),
            ),
          ],
        );
      },
    );
  }
}
