import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../../app/design_tokens.dart';

class ClayProgressRing extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double size;
  final double strokeWidth;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? glowColor;
  final Widget? child;
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;

  const ClayProgressRing({
    super.key,
    required this.progress,
    this.size = 64,
    this.strokeWidth = 6,
    this.progressColor,
    this.backgroundColor,
    this.glowColor,
    this.child,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
  });

  @override
  State<ClayProgressRing> createState() => _ClayProgressRingState();
}

class _ClayProgressRingState extends State<ClayProgressRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.animationDuration);
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );
    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant ClayProgressRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(begin: _previousProgress, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: widget.animationCurve),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressColor = widget.progressColor ?? ClayTokens.clayPrimary;
    final bgColor = widget.backgroundColor ??
        (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder);
    final glowColor = widget.glowColor ?? progressColor;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.size, widget.size),
            painter: _ProgressRingPainter(
              progress: _animation.value,
              strokeWidth: widget.strokeWidth,
              progressColor: progressColor,
              backgroundColor: bgColor,
              glowColor: glowColor,
            ),
            child: widget.child != null
                ? Center(child: widget.child)
                : Center(
                    child: Text(
                      '${(_animation.value * 100).round()}%',
                      style: ClayTokens.headlineSmall.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary,
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color backgroundColor;
  final Color glowColor;

  _ProgressRingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.backgroundColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress ring
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * 3.14159 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start at top
      sweepAngle,
      false,
      progressPaint,
    );

    // Glow effect on progress end
    if (progress > 0) {
      final glowPaint = Paint()
        ..color = glowColor.withAlpha(100)
        ..strokeWidth = strokeWidth * 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _ProgressRingPainter &&
        (oldDelegate.progress != progress ||
            oldDelegate.strokeWidth != strokeWidth ||
            oldDelegate.progressColor != progressColor);
  }
}

/// Linear progress bar with clay styling
class ClayProgressBar extends StatefulWidget {
  final double progress; // 0.0 to 1.0
  final double height;
  final double borderRadius;
  final Color? progressColor;
  final Color? backgroundColor;
  final Color? glowColor;
  final bool animate;
  final Duration animationDuration;
  final Curve animationCurve;
  final Widget? label;
  final bool showPercentage;

  const ClayProgressBar({
    super.key,
    required this.progress,
    this.height = 8,
    this.borderRadius = 4,
    this.progressColor,
    this.backgroundColor,
    this.glowColor,
    this.animate = true,
    this.animationDuration = const Duration(milliseconds: 200),
    this.animationCurve = Curves.easeOutCubic,
    this.label,
    this.showPercentage = false,
  });

  @override
  State<ClayProgressBar> createState() => _ClayProgressBarState();
}

class _ClayProgressBarState extends State<ClayProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousProgress = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.animationDuration);
    _animation = Tween<double>(begin: 0, end: widget.progress).animate(
      CurvedAnimation(parent: _controller, curve: widget.animationCurve),
    );
    if (widget.animate) _controller.forward();
  }

  @override
  void didUpdateWidget(covariant ClayProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.progress != widget.progress) {
      _previousProgress = _animation.value;
      _animation = Tween<double>(begin: _previousProgress, end: widget.progress).animate(
        CurvedAnimation(parent: _controller, curve: widget.animationCurve),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progressColor = widget.progressColor ?? ClayTokens.clayPrimary;
    final bgColor = widget.backgroundColor ??
        (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder);
    final glowColor = widget.glowColor ?? progressColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null || widget.showPercentage) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (widget.label != null) widget.label!,
              if (widget.showPercentage)
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, _) => Text(
                    '${(_animation.value * 100).round()}%',
                    style: ClayTokens.labelSmall.copyWith(
                      color: isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: ClayTokens.xs),
        ],
        AnimatedBuilder(
          animation: _animation,
          builder: (context, _) {
            return Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withAlpha(50),
                    offset: const Offset(0, 2),
                    blurRadius: 4,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Stack(
                children: [
                  // Background
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(widget.borderRadius),
                    ),
                  ),
                  // Progress
                  FractionallySizedBox(
                    widthFactor: _animation.value.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [progressColor, progressColor.withAlpha(200)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(widget.borderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: glowColor.withAlpha(80),
                            offset: const Offset(0, 0),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ).animate(target: _animation.value * 100).scaleX(
              alignment: Alignment.centerLeft,
              duration: widget.animate ? widget.animationDuration : Duration.zero,
              curve: widget.animationCurve,
            );
          },
        ),
      ],
    );
  }
}

/// Step progress indicator
class ClayStepProgress extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String>? labels;
  final Color? activeColor;
  final Color? inactiveColor;
  final double lineHeight;
  final double nodeSize;

  const ClayStepProgress({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    this.labels,
    this.activeColor,
    this.inactiveColor,
    this.lineHeight = 3,
    this.nodeSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final active = activeColor ?? ClayTokens.clayPrimary;
    final inactive = inactiveColor ?? (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder);

    return Column(
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        final isLast = index == totalSteps - 1;
        final isCurrent = index == currentStep;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                AnimatedContainer(
                  duration: ClayTokens.normal,
                  curve: ClayTokens.easeOut,
                  width: nodeSize,
                  height: nodeSize,
                  decoration: BoxDecoration(
                    color: isActive ? active : inactive,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? active : (isDark ? ClayTokens.clayDarkBase : ClayTokens.clayBase),
                      width: isCurrent ? 3 : 0,
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: active.withAlpha(60),
                              offset: const Offset(0, 4),
                              blurRadius: 12,
                              spreadRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: isActive
                      ? Center(
                          child: Icon(
                            isLast ? Icons.check : Icons.check,
                            size: nodeSize * 0.5,
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                if (!isLast)
                  Container(
                    width: lineHeight,
                    height: (labels != null ? 60 : 40),
                    color: index < currentStep ? active : inactive,
                  ),
              ],
            ),
            SizedBox(width: ClayTokens.md),
            if (labels != null && index < labels!.length)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: ClayTokens.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        labels![index],
                        style: ClayTokens.bodyMedium.copyWith(
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive
                              ? (isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary)
                              : (isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary),
                        ),
                      ),
                      if (index == currentStep && !isLast)
                        Text(
                          'Current step',
                          style: ClayTokens.labelSmall.copyWith(
                            color: active,
                          ),
                        ),
                    ],
                  ),
                ),
            ),
          ],
        );
      }),
    );
  }
}

/// Skeleton loader with clay styling
class ClaySkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Duration duration;

  const ClaySkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<ClaySkeleton> createState() => _ClaySkeletonState();
}

class _ClaySkeletonState extends State<ClaySkeleton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = Tween<double>(begin: -1, end: 2).animate(_controller);
    _controller.repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? ClayTokens.clayDarkCard : ClayTokens.clayCard;
    final highlightColor = isDark ? ClayTokens.clayDarkCardHover : ClayTokens.clayCardHover;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: widget.borderRadius ?? BorderRadius.circular(ClayTokens.radiusButton),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_animation.value - 0.3).clamp(0, 1),
                _animation.value.clamp(0, 1),
                (_animation.value + 0.3).clamp(0, 1),
              ],
            ).createShader(bounds),
            blendMode: BlendMode.srcATop,
            child: Container(
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(ClayTokens.radiusButton),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Circular skeleton
class ClaySkeletonCircle extends StatelessWidget {
  final double size;
  final Duration duration;

  const ClaySkeletonCircle({super.key, this.size = 48, this.duration = const Duration(milliseconds: 1500)});

  @override
  Widget build(BuildContext context) {
    return ClaySkeleton(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
      duration: duration,
    );
  }
}

/// Multi-line skeleton block
class ClaySkeletonBlock extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double spacing;
  final double lastLineWidthFactor;

  const ClaySkeletonBlock({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.spacing = 8,
    this.lastLineWidthFactor = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: index == lines - 1 ? 0 : spacing),
          child: ClaySkeleton(
            width: isLast ? double.infinity : double.infinity,
            height: lineHeight,
            borderRadius: BorderRadius.circular(ClayTokens.radiusXs),
          ),
        );
      }),
    );
  }
}