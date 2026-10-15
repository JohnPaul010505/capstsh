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
          .eq('goal_category', 'workout')
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

  // ── Food (daily calorie) goal widget ──────────────────────────────────────
  // A second, independent launcher widget that mirrors the member's running
  // FOOD goal. It is visually the twin of the workout widget but its ring
  // shows TODAY's consumed calories against the DAILY target, so the numbers
  // and the Android side never mix with the weight widget's `goal_*` keys.

  static const foodProviderName =
      'com.example.fitness_app.FoodGoalWidgetProvider';

  /// Refreshes the food widget for the signed-in member: the newest running
  /// food goal plus today's logged calories. Called when the Goals screen
  /// creates/cancels a food goal so the launcher never shows stale numbers.
  static Future<void> syncFoodForCurrentMember() async {
    if (!Platform.isAndroid) return;
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) {
        await clearFood();
        return;
      }

      final goals = await client
          .from('goals')
          .select('id,title,goal_type,target_value,start_date,end_date,status')
          .eq('member_id', userId)
          .eq('status', 'active')
          .eq('goal_category', 'food')
          .order('created_at', ascending: false)
          .limit(1);
      if (goals.isEmpty) {
        await _writeFoodEmpty();
        return;
      }

      final consumedToday = await _todayCalories(userId);
      await syncFoodGoal(goals.first, consumedToday: consumedToday);
    } catch (error) {
      debugPrint('Food goal home widget refresh failed: $error');
    }
  }

  static Future<void> clear() async {
    if (!Platform.isAndroid) return;
    try {
      await _writeEmpty();
    } catch (error) {
      debugPrint('Goal home widget clear failed: $error');
    }
  }

  /// Pushes one food goal (and the calories already logged today) to the food
  /// widget. `consumedToday` is passed in by the card so the ring matches what
  /// the member is looking at, without a second round-trip to the DB.
  static Future<void> syncFoodGoal(
    Map<String, dynamic> goal, {
    required int consumedToday,
  }) async {
    if (!Platform.isAndroid) return;
    final title = goal['title'] as String? ?? 'Daily calorie goal';
    final target = (goal['target_value'] as num?)?.toDouble() ?? 0;
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

    final remaining = (target - consumedToday).round();
    final pct = target > 0
        ? ((consumedToday / target) * 100).clamp(0, 100).toDouble()
        : 0.0;

    await HomeWidget.saveWidgetData<bool>('food_goal_has_active', true);
    await HomeWidget.saveWidgetData<String>('food_goal_title', title);
    await HomeWidget.saveWidgetData<String>(
      'food_goal_target',
      '${target.toStringAsFixed(0)} kcal',
    );
    await HomeWidget.saveWidgetData<String>(
      'food_goal_today',
      '$consumedToday kcal',
    );
    await HomeWidget.saveWidgetData<String>(
      'food_goal_left',
      '${remaining < 0 ? -remaining : remaining} kcal',
    );
    await HomeWidget.saveWidgetData<bool>('food_goal_over', remaining < 0);
    await HomeWidget.saveWidgetData<String>('food_goal_end_date', endDateOnly);
    await HomeWidget.saveWidgetData<double>('food_goal_progress_pct', pct);
    await HomeWidget.saveWidgetData<int>('food_goal_days_left', daysLeft);
    await HomeWidget.renderFlutterWidget(
      _GoalWidgetRing(progress: pct),
      key: 'food_goal_progress_ring',
      logicalSize: const Size(112, 112),
      pixelRatio: 2,
    );
    await HomeWidget.updateWidget(qualifiedAndroidName: foodProviderName);
  }

  static Future<bool> requestFoodPin() async {
    if (!Platform.isAndroid) return false;
    final supported = await HomeWidget.isRequestPinWidgetSupported();
    if (supported != true) return false;
    await HomeWidget.requestPinWidget(qualifiedAndroidName: foodProviderName);
    return true;
  }

  static Future<void> clearFood() async {
    if (!Platform.isAndroid) return;
    try {
      await _writeFoodEmpty();
    } catch (error) {
      debugPrint('Food goal home widget clear failed: $error');
    }
  }

  static Future<void> _writeFoodEmpty() async {
    await HomeWidget.saveWidgetData<bool>('food_goal_has_active', false);
    await HomeWidget.saveWidgetData<String>('food_goal_title', 'No food goal');
    await HomeWidget.saveWidgetData<String>('food_goal_target', '—');
    await HomeWidget.saveWidgetData<String>('food_goal_today', '—');
    await HomeWidget.saveWidgetData<String>('food_goal_left', '—');
    await HomeWidget.saveWidgetData<bool>('food_goal_over', false);
    await HomeWidget.saveWidgetData<String>('food_goal_end_date', '');
    await HomeWidget.saveWidgetData<double>('food_goal_progress_pct', 0);
    await HomeWidget.saveWidgetData<int>('food_goal_days_left', 0);
    await HomeWidget.saveWidgetData<String>('food_goal_progress_ring', '');
    await HomeWidget.updateWidget(qualifiedAndroidName: foodProviderName);
  }

  /// Total calories logged today for [userId]. Mirrors todayCaloriesProvider's
  /// window so the widget and the in-app card never disagree.
  static Future<int> _todayCalories(String userId) async {
    final client = SupabaseClientService().client;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final rows = await client
        .from('meal_logs')
        .select('calories')
        .eq('member_id', userId)
        .gte('meal_time', startOfDay.toUtc().toIso8601String())
        .lt('meal_time', endOfDay.toUtc().toIso8601String());
    var total = 0;
    for (final r in (rows as List).cast<Map<String, dynamic>>()) {
      total += (r['calories'] as int? ?? 0);
    }
    return total;
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
