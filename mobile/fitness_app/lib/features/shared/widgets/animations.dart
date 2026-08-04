import 'package:flutter/material.dart';

class StaggeredFadeIn extends StatefulWidget {
  final int index;
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Curve curve;
  final Offset offset;

  const StaggeredFadeIn({
    super.key,
    required this.index,
    required this.child,
    this.delay = const Duration(milliseconds: 40),
    this.duration = const Duration(milliseconds: 350),
    this.curve = Curves.easeOut,
    this.offset = const Offset(0, 12),
  });

  @override
  State<StaggeredFadeIn> createState() => _StaggeredFadeInState();
}

class _StaggeredFadeInState extends State<StaggeredFadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    _slide = Tween<Offset>(begin: widget.offset, end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: widget.curve),
    );
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _controller.forward();
    });
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
      builder: (_, __) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(
          offset: _slide.value,
          child: widget.child,
        ),
      ),
    );
  }
}

class AnimatedCountUp extends StatefulWidget {
  final int target;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;

  const AnimatedCountUp({
    super.key,
    required this.target,
    this.style,
    this.duration = const Duration(milliseconds: 800),
    this.curve = Curves.easeOut,
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _displayValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: widget.curve);
    _controller.addListener(() {
      setState(() {
        _displayValue = (_animation.value * widget.target).round();
      });
    });
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _controller.reset();
      _displayValue = 0;
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text('$_displayValue', style: widget.style);
  }
}

class AnimatedPulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const AnimatedPulseDot({super.key, this.color = const Color(0xFF30D158), this.size = 8});

  @override
  State<AnimatedPulseDot> createState() => _AnimatedPulseDotState();
}

class _AnimatedPulseDotState extends State<AnimatedPulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _pulse = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        width: widget.size * _pulse.value,
        height: widget.size * _pulse.value,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class Shimmer extends StatefulWidget {
  final Widget child;

  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: -1, end: 2).animate(
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
      builder: (_, __) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0xFF2C2C2E), Color(0xFF3A3A3C), Color(0xFF2C2C2E)],
          stops: [_animation.value.clamp(0, 1), (_animation.value + 0.3).clamp(0, 1), (_animation.value + 0.6).clamp(0, 1)],
        ).createShader(bounds),
        blendMode: BlendMode.srcOver,
        child: widget.child,
      ),
    );
  }
}
