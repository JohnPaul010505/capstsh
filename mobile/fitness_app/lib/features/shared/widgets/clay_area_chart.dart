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

  /// When true, paints the exact value centered above each non-null dot.
  final bool showValueLabels;

  const ClayAreaChart({
    super.key,
    required this.values,
    required this.labels,
    required this.strokeColor,
    this.height = 90,
    this.emptyMessage = 'No data yet',
    this.legendLabel,
    this.showYAxis = false,
    this.showValueLabels = false,
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
                    labels: labels,
                    strokeColor: strokeColor,
                    minY: nonNull.reduce(min),
                    maxY: nonNull.reduce(max),
                    showYAxis: showYAxis,
                    showValueLabels: showValueLabels,
                  ),
                ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double?> values;
  final List<String> labels;
  final Color strokeColor;
  final double minY;
  final double maxY;
  final bool showYAxis;
  final bool showValueLabels;

  _AreaChartPainter({
    required this.values,
    required this.labels,
    required this.strokeColor,
    required this.minY,
    required this.maxY,
    this.showYAxis = false,
    this.showValueLabels = false,
  });

  static const double _gutter = 30;

  /// Reserved band at the bottom for the month labels. The plot area maps
  /// above it so dots/lines never collide with label text.
  static const double _labelBand = 16;

  /// Top padding carved out so the highest dot still leaves room for a value
  /// label above it.
  static const double _topPad = 18;

  @override
  void paint(Canvas canvas, Size size) {
    final range = (maxY - minY).clamp(0.1, double.infinity).toDouble();
    final haveValues = showYAxis || showValueLabels;
    final topPad = haveValues ? _topPad : size.height * 0.08;
    final bottom = size.height - _labelBand;
    final plotHeight = (bottom - topPad).clamp(1.0, double.infinity).toDouble();
    final gutter = showYAxis ? _gutter : 0.0;
    final plotWidth = (size.width - gutter).clamp(1.0, double.infinity).toDouble();
    double xFor(int i) => values.length == 1
        ? gutter + plotWidth / 2
        : gutter + i * plotWidth / (values.length - 1);
    double yFor(double v) => topPad + (1 - (v - minY) / range) * plotHeight;

    // Dashed grid lines (start after the Y-axis gutter when visible)
    final gridPaint = Paint()
      ..color = ClayTokens.clayDarkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = topPad + f * plotHeight;
      for (double x = gutter; x < size.width; x += 6) {
        canvas.drawLine(
          Offset(x, y),
          Offset(min(x + 3, size.width), y),
          gridPaint,
        );
      }
    }

    if (showYAxis) {
      _drawYAxis(canvas, size, topPad, plotHeight, range, gutter);
    }

    // Data points
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      pts.add(Offset(xFor(i), yFor(v)));
    }
    if (pts.isEmpty) return;

    // Gradient fill (clipped to the plotting area so it never spills
    // into the label band).
    final path = Path()
      ..moveTo(pts.first.dx, bottom);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path
      ..lineTo(pts.last.dx, bottom)
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
        ).createShader(Rect.fromLTWH(0, topPad, size.width, plotHeight)),
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

    // Exact value labels. Colliding labels stagger upward (or drop below the
    // dot) instead of being hidden, so every data point shows its value.
    if (showValueLabels) {
      _drawValueLabels(canvas, size, topPad, bottom, xFor, yFor);
    }

    // Month labels inside the reserved band, centered at each dot's X.
    _drawMonthLabels(canvas, size, bottom, xFor);
  }

  void _drawValueLabels(
    Canvas canvas,
    Size size,
    double topPad,
    double bottom,
    double Function(int) xFor,
    double Function(double) yFor,
  ) {
    final placed = <Rect>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      final text = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: strokeColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final cx = xFor(i);
      final cy = yFor(v);
      final left = (cx - tp.width / 2).clamp(0.0, size.width - tp.width);

      // Prefer the label centered above the dot. If it collides with an
      // already-placed label, nudge it higher in steps; if it would leave the
      // plot, drop it below the dot instead.
      final aboveRect = Rect.fromLTWH(left, cy - tp.height - 5, tp.width, tp.height);
      var rect = aboveRect;
      var finalAbove = true;
      var guard = 0;
      while (_overlaps(rect, placed) && guard < 6) {
        rect = rect.translate(0, -13);
        if (rect.top < topPad) {
          finalAbove = false;
          break;
        }
        guard++;
      }
      if (!finalAbove || _overlaps(rect, placed)) {
        var below = Rect.fromLTWH(left, cy + 5, tp.width, tp.height);
        if (below.bottom > bottom + _labelBand) {
          below = Rect.fromLTWH(left, cy - tp.height - 5, tp.width, tp.height);
        }
        rect = below;
      }

      tp.paint(canvas, rect.topLeft);
      placed.add(rect);
      final tickTop = rect.bottom + 1;
      canvas.drawLine(
        Offset(cx, tickTop),
        Offset(cx, min(cy - 4, tickTop)),
        Paint()
          ..color = strokeColor.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
    }
  }

  bool _overlaps(Rect a, List<Rect> placed) {
    for (final r in placed) {
      if (a.overlaps(r)) return true;
    }
    return false;
  }

  void _drawMonthLabels(
    Canvas canvas,
    Size size,
    double plotBottom,
    double Function(int) xFor,
  ) {
    final top = plotBottom + 3;
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            fontSize: 9,
            color: ClayTokens.clayDarkTextTertiary,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = xFor(i).clamp(tp.width / 2 + 2, size.width - tp.width / 2 - 2);
      tp.paint(canvas, Offset(cx - tp.width / 2, top));
    }
  }

  /// Integer value labels at the top/middle/bottom of the Y axis with ticks,
  /// aligned to the same scale the plot uses.
  void _drawYAxis(Canvas canvas, Size size, double topPad, double plotHeight, double range, double gutter) {
    final tickPaint = Paint()
      ..color = ClayTokens.clayDarkBorder.withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = topPad + (1 - f) * plotHeight;
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
      old.labels != labels ||
      old.strokeColor != strokeColor ||
      old.minY != minY ||
      old.maxY != maxY ||
      old.showYAxis != showYAxis ||
      old.showValueLabels != showValueLabels;
}
