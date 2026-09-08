import 'package:flutter/material.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

class GoalProgressLinear extends StatelessWidget {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double height;

  const GoalProgressLinear({
    super.key,
    required this.progress,
    this.progressColor = highlightPurple,
    this.backgroundColor = const Color(0xFF2A2A45),
    this.height = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation(progressColor),
        minHeight: height,
      ),
    );
  }
}

class GoalProgressCircular extends StatelessWidget {
  final double progress;
  final Color progressColor;
  final Color backgroundColor;
  final double size;
  final double strokeWidth;
  final String? label;

  const GoalProgressCircular({
    super.key,
    required this.progress,
    this.progressColor = highlightPurple,
    this.backgroundColor = const Color(0xFF2A2A45),
    this.size = 56,
    this.strokeWidth = 5,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final displayLabel = label ?? '${(progress * 100).toStringAsFixed(0)}%';
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: backgroundColor,
            color: progressColor,
            strokeWidth: strokeWidth,
          ),
          Text(
            displayLabel,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: size * 0.22,
            ),
          ),
        ],
      ),
    );
  }
}
