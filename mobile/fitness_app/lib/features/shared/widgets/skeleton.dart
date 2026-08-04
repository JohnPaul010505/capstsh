import 'package:flutter/material.dart';

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, __) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              colors: const [
                Color(0xFF2C2C2E),
                Color(0xFF3A3A3C),
                Color(0xFF2C2C2E),
              ],
              stops: [
                (_animation.value - 0.5).clamp(0.0, 1.0),
                _animation.value.clamp(0.0, 1.0),
                (_animation.value + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SkeletonCard extends StatelessWidget {
  final double height;
  final int lines;

  const SkeletonCard({super.key, this.height = 80, this.lines = 2});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2C2C2E).withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...List.generate(lines, (i) => Padding(
            padding: EdgeInsets.only(bottom: i < lines - 1 ? 10 : 0),
            child: SkeletonBox(
              width: i == 0 ? 180 : double.infinity,
              height: 12,
            ),
          )),
        ],
      ),
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      physics: const ClampingScrollPhysics(),
      children: const [
        SizedBox(height: 14),
        SkeletonBox(width: 200, height: 20),
        SizedBox(height: 8),
        Row(
          children: [
            SkeletonBox(width: 44, height: 44, borderRadius: 22),
            SizedBox(width: 10),
            Expanded(child: SizedBox()),
          ],
        ),
        SizedBox(height: 12),
        SkeletonCard(height: 100),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 70)),
            SizedBox(width: 8),
            Expanded(child: SkeletonCard(height: 70)),
            SizedBox(width: 8),
            Expanded(child: SkeletonCard(height: 70)),
          ],
        ),
        SizedBox(height: 8),
        SkeletonCard(height: 70),
        SizedBox(height: 8),
        SkeletonCard(height: 100),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: SkeletonCard(height: 100)),
            SizedBox(width: 10),
            Expanded(child: SkeletonCard(height: 100)),
          ],
        ),
        SizedBox(height: 16),
      ],
    );
  }
}
