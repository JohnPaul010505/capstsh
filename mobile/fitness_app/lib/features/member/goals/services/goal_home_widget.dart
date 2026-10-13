import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared/services/supabase_client.dart';

import '../../../shared/utils/goal_progress.dart';

/// Keeps the Android launcher widget in sync with the member's active goal.
/// Widget data is local to this app install; no credentials are copied out of
/// Supabase and Android only refreshes the cached view periodically.
abstract final class GoalHomeWidget {
  // home_widget resolves qualifiedAndroidName literally. Passing the same
  // fully qualified value as androidName makes the plugin prepend the app id
  // a second time (com.example.fitness_app.com.example.fitness_app...).
  static const providerName = 'com.example.fitness_app.GoalWidgetProvider';

  static Future<void> syncForCurrentMember() async {
    if (!Platform.isAndroid) return;
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        await clear();
        return;
      }

      final goals = await client
          .from('goals')
          .select(
            'id,title,goal_type,target_value,current_value,start_date,end_date,status',
          )
          .eq('member_id', userId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1);
      if (goals.isEmpty) {
        await _writeEmpty();
        return;
      }

      final measurements = await client
          .from('body_measurements')
          .select('weight_kg')
          .eq('member_id', userId)
          .order('measured_at', ascending: false)
          .limit(1);
      final liveWeight = measurements.isEmpty
          ? null
          : (measurements.first['weight_kg'] as num?)?.toDouble();
      await syncGoal(goals.first, liveWeight: liveWeight);
    } catch (error) {
      debugPrint('Goal home widget refresh failed: $error');
    }
  }

  static Future<void> syncGoal(
    Map<String, dynamic> goal, {
    double? liveWeight,
  }) async {
    if (!Platform.isAndroid) return;
    final title = goal['title'] as String? ?? 'Fitness goal';
    final type = goal['goal_type'] as String? ?? '';
    final baseline = (goal['current_value'] as num?)?.toDouble();
    final target = (goal['target_value'] as num?)?.toDouble();
    final current = liveWeight ?? baseline;
    final progress = computeGoalProgress(
      baseline: baseline,
      target: target,
      live: current,
      goalType: type,
    );
    final endDate = DateTime.tryParse(goal['end_date']?.toString() ?? '');
    final endDateOnly = endDate == null
        ? ''
        : '${endDate.year.toString().padLeft(4, '0')}-${endDate.month.toString().padLeft(2, '0')}-${endDate.day.toString().padLeft(2, '0')}';
    final daysLeft = endDate == null
        ? 0
        : DateUtils.dateOnly(endDate)
              .difference(DateUtils.dateOnly(DateTime.now()))
              .inDays
              .clamp(0, 3650);
    final unit = _unit(type);

    await HomeWidget.saveWidgetData<bool>('goal_has_active', true);
    await HomeWidget.saveWidgetData<String>('goal_title', title);
    await HomeWidget.saveWidgetData<String>('goal_type', type);
    await HomeWidget.saveWidgetData<String>(
      'goal_target',
      _format(target, unit),
    );
    await HomeWidget.saveWidgetData<String>(
      'goal_current',
      _format(current, unit),
    );
    await HomeWidget.saveWidgetData<String>(
      'goal_remaining',
      _format(progress.remaining?.clamp(0, double.infinity), unit),
    );
    await HomeWidget.saveWidgetData<String>('goal_end_date', endDateOnly);
    await HomeWidget.saveWidgetData<double>('goal_progress_pct', progress.pct);
    await HomeWidget.saveWidgetData<int>('goal_days_left', daysLeft);
    await HomeWidget.renderFlutterWidget(
      _GoalWidgetRing(progress: progress.pct),
      key: 'goal_progress_ring',
      logicalSize: const Size(112, 112),
      pixelRatio: 2,
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
  }

  static Future<bool> requestPin() async {
    if (!Platform.isAndroid) return false;
    final supported = await HomeWidget.isRequestPinWidgetSupported();
    if (supported != true) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: providerName);
    return true;
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await _writeEmpty();
    } catch (error) {
      debugPrint('Goal home widget clear failed: $error');
    }
  }

  static Future<void> _writeEmpty() async {
    await HomeWidget.saveWidgetData<bool>('goal_has_active', false);
    await HomeWidget.saveWidgetData<String>('goal_title', 'No active goal');
    await HomeWidget.saveWidgetData<String>(
      'goal_type',
      'Create a goal to see your progress here.',
    );
    await HomeWidget.saveWidgetData<String>('goal_target', '—');
    await HomeWidget.saveWidgetData<String>('goal_current', '—');
    await HomeWidget.saveWidgetData<String>('goal_remaining', '—');
    await HomeWidget.saveWidgetData<String>('goal_end_date', '');
    await HomeWidget.saveWidgetData<int>('goal_days_left', 0);
    await HomeWidget.saveWidgetData<double>('goal_progress_pct', 0);
    await HomeWidget.saveWidgetData<String>('goal_progress_ring', '');
    await HomeWidget.updateWidget(qualifiedAndroidName: providerName);
  }

  static String _unit(String type) =>
      const {
        'lose weight',
        'gain muscle',
        'maintain weight',
      }.contains(type.toLowerCase())
      ? 'kg'
      : '';

  static String _format(double? value, String unit) => value == null
      ? '—'
      : '${value.toStringAsFixed(1)}${unit.isEmpty ? '' : ' $unit'}';
}

class _GoalWidgetRing extends StatelessWidget {
  const _GoalWidgetRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 112,
    height: 112,
    child: CustomPaint(
      painter: _GoalRingPainter(progress.clamp(0, 100)),
      child: Center(
        child: Text(
          '${progress.clamp(0, 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
      ),
    ),
  );
}

class _GoalRingPainter extends CustomPainter {
  const _GoalRingPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.36;
    final rect = Rect.fromCircle(center: center, radius: radius);
    const strokeWidth = 9.0;

    canvas.drawCircle(
      center,
      radius + 13,
      Paint()
        ..color = const Color(0x447C3AED)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      center,
      radius + 13,
      Paint()
        ..color = const Color(0xF0191737)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      center,
      radius + 13,
      Paint()
        ..color = const Color(0x614D3C91)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawArc(
      rect,
      0,
      2 * 3.141592653589793,
      false,
      Paint()
        ..color = const Color(0xFF3D356B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final sweep = 2 * 3.141592653589793 * (progress / 100);
    if (sweep > 0) {
      final arcPaint = Paint()
        ..shader = const SweepGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFC026D3)],
          startAngle: -1.5707963267948966,
          endAngle: 4.71238898038469,
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        rect,
        -1.5707963267948966,
        sweep.clamp(0, 2 * 3.141592653589793),
        false,
        Paint()
          ..color = const Color(0x667C3AED)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 17
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
      canvas.drawArc(
        rect,
        -1.5707963267948966,
        sweep.clamp(0, 2 * 3.141592653589793),
        false,
        arcPaint,
      );
      final endAngle = -1.5707963267948966 + sweep;
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(endAngle),
          center.dy + radius * math.sin(endAngle),
        ),
        strokeWidth / 2,
        Paint()..color = const Color(0xFFC026D3),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GoalRingPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
