import 'dart:math';

import 'package:flutter/material.dart';

import '../../../app/design_tokens.dart';

class ClayAreaChart extends StatelessWidget {
  final List<double?> values;
  final List<String> labels;
  final Color strokeColor;
  final double height;
  final String emptyMessage;

  /// When set, renders a legend row (colored dot + label) above the chart.
  final String? legendLabel;

  /// When true, reserves a left gutter and paints integer Y-axis value labels
  /// (min/mid/max) with matching gridlines aligned to the plotted scale.
  final bool showYAxis;

  const ClayAreaChart({
    super.key,
    required this.values,
    required this.labels,
    required this.strokeColor,
    this.height = 90,
    this.emptyMessage = 'No data yet',
    this.legendLabel,
    this.showYAxis = false,
  });

  @override
  Widget build(BuildContext context) {
    final nonNull = values.whereType<double>().toList();
    return Column(
      children: [
        if (legendLabel != null) ...[
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: strokeColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                legendLabel!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: height,
          child: nonNull.isEmpty
              ? Center(
                  child: Text(
                    emptyMessage,
                    style: ClayTokens.darkBodySmall
                        .copyWith(color: ClayTokens.clayDarkTextTertiary),
                  ),
                )
              : CustomPaint(
                  size: Size(double.infinity, height),
                  painter: _AreaChartPainter(
                    values: values,
                    strokeColor: strokeColor,
                    minY: nonNull.reduce(min),
                    maxY: nonNull.reduce(max),
                    showYAxis: showYAxis,
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(
            labels.length,
            (i) => Expanded(
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double?> values;
  final Color strokeColor;
  final double minY;
  final double maxY;
  final bool showYAxis;

  _AreaChartPainter({
    required this.values,
    required this.strokeColor,
    required this.minY,
    required this.maxY,
    this.showYAxis = false,
  });

  static const double _gutter = 30;

  @override
  void paint(Canvas canvas, Size size) {
    final range = (maxY - minY).clamp(0.1, double.infinity).toDouble();
    final pad = size.height * 0.08;
    final gutter = showYAxis ? _gutter : 0.0;
    final plotWidth = (size.width - gutter).clamp(1.0, double.infinity).toDouble();
    double xFor(int i) => values.length == 1
        ? gutter + plotWidth / 2
        : gutter + i * plotWidth / (values.length - 1);
    double yFor(double v) =>
        pad + (1 - (v - minY) / range) * (size.height - pad * 2);

    // Dashed grid lines (start after the Y-axis gutter when visible)
    final gridPaint = Paint()
      ..color = ClayTokens.clayDarkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = size.height * f;
      for (double x = gutter; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(min(x + 3, size.width), y),
          gridPaint,
        );
      }
    }

    if (showYAxis) {
      _drawYAxis(canvas, size, pad, range, gutter);
    }

    // Data points
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      pts.add(Offset(xFor(i), yFor(v)));
    }
    if (pts.isEmpty) return;

    // Gradient fill
    final path = Path()
      ..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(pts.last.dx, size.height)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            strokeColor.withValues(alpha: 0.25),
            strokeColor.withValues(alpha: 0.02),
          ],
        ).createShader(Offset.zero & size),
    );

    // Line
    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final linePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts) {
      linePath.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(linePath, linePaint);

    // Dots with white ring
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = strokeColor);
      canvas.drawCircle(
        p,
        3,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke,
      );
    }
  }

  /// Integer value labels at the top/middle/bottom of the Y axis with ticks,
  /// aligned to the same scale the plot uses.
  void _drawYAxis(Canvas canvas, Size size, double pad, double range, double gutter) {
    final tickPaint = Paint()
      ..color = ClayTokens.clayDarkBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = pad + (1 - f) * (size.height - pad * 2);
      final value = maxY - f * range;
      final label = value % 1 == 0
          ? value.toInt().toString()
          : value.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9,
            color: ClayTokens.clayDarkTextTertiary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: gutter - 4);
      tp.paint(canvas, Offset(gutter - 4 - tp.width, y - tp.height / 2));
      canvas.drawLine(Offset(gutter - 3, y), Offset(gutter, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.values != values ||
      old.strokeColor != strokeColor ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.showYAxis != showYAxis;
}
