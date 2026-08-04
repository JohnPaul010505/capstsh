import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

final memberProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final client = SupabaseClientService().client;
  final response = await client.from('profiles').select('id, full_name').eq('id', id).single();
  return response;
});

final memberWorkoutsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final response = await SupabaseClientService()
      .client
      .from('workout_logs')
      .select()
      .eq('member_id', id)
      .gte('logged_at', '${today}T00:00:00')
      .lt('logged_at', '${today}T23:59:59')
      .order('logged_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

final memberMealsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final response = await SupabaseClientService()
      .client
      .from('meal_logs')
      .select('food_name, calories, meal_type, meal_time')
      .eq('member_id', id)
      .gte('meal_time', '${today}T00:00:00')
      .lt('meal_time', '${today}T23:59:59')
      .order('meal_time', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

final memberWeightProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final response = await SupabaseClientService()
      .client
      .from('body_measurements')
      .select('weight_kg, measured_at')
      .eq('member_id', id)
      .order('measured_at', ascending: false)
      .limit(10);
  return (response as List).cast<Map<String, dynamic>>();
});

final memberGoalsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, id) async {
  final response = await SupabaseClientService()
      .client
      .from('goals')
      .select('title, status, created_at')
      .eq('member_id', id)
      .order('created_at', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});

class MemberProgressPage extends ConsumerStatefulWidget {
  final String id;
  const MemberProgressPage({super.key, required this.id});

  @override
  ConsumerState<MemberProgressPage> createState() => _MemberProgressPageState();
}

class _MemberProgressPageState extends ConsumerState<MemberProgressPage> {
  final _feedbackController = TextEditingController();
  StreamSubscription? _workoutSub;
  StreamSubscription? _mealSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeWorkouts();
      _subscribeMeals();
    });
  }

  void _subscribeWorkouts() {
    _workoutSub?.cancel();
    _workoutSub = SupabaseClientService()
        .client
        .from('workout_logs')
        .stream(primaryKey: ['id'])
        .eq('member_id', widget.id)
        .order('logged_at', ascending: false)
        .limit(1)
        .listen((_) => ref.invalidate(memberWorkoutsProvider(widget.id)));
  }

  void _subscribeMeals() {
    _mealSub?.cancel();
    _mealSub = SupabaseClientService()
        .client
        .from('meal_logs')
        .stream(primaryKey: ['id'])
        .eq('member_id', widget.id)
        .order('meal_time', ascending: false)
        .limit(1)
        .listen((_) => ref.invalidate(memberMealsProvider(widget.id)));
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    if (text.isEmpty) return;
    try {
      final userId = SupabaseClientService().client.auth.currentUser!.id;
      await SupabaseClientService().client.from('trainer_feedback').insert({
        'trainer_id': userId,
        'member_id': widget.id,
        'content': text,
      });
      _feedbackController.clear();
      if (mounted) _showSnack('Feedback sent');
    } catch (_) {
      if (mounted) _showSnack('Error sending feedback');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  void dispose() {
    _workoutSub?.cancel();
    _mealSub?.cancel();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(memberProfileProvider(widget.id));
    final workoutsAsync = ref.watch(memberWorkoutsProvider(widget.id));
    final mealsAsync = ref.watch(memberMealsProvider(widget.id));
    final weightAsync = ref.watch(memberWeightProvider(widget.id));
    final goalsAsync = ref.watch(memberGoalsProvider(widget.id));

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (profile) {
            final name = profile['full_name'] as String? ?? 'Member';
            final initials = name.split(' ').map((n) => n[0]).take(2).join();
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              physics: const ClampingScrollPhysics(),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(CupertinoIcons.chevron_back, color: ClayTokens.clayDarkTextPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ClayTokens.clayDarkSurfaceElevated,
                      ),
                      alignment: Alignment.center,
                      child: Text(initials, style: ClayTokens.titleLarge.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary)),
                    ),
                    const SizedBox(width: 10),
                    Text(name, style: ClayTokens.titleLarge.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.24)),
                  ],
                ),
                const SizedBox(height: 16),

                // Weight trend
                Text('Weight Trend', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                const SizedBox(height: 8),
                weightAsync.when(
                  data: (weights) => _WeightChart(weights: weights),
                  loading: () => const _ChartSkeleton(),
                  error: (_, __) => const _ChartSkeleton(),
                ),

                // Today's Workouts
                const SizedBox(height: 14),
                Text("Today's Workouts", style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                const SizedBox(height: 8),
                workoutsAsync.when(
                  data: (workouts) => workouts.isEmpty
                      ? Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('No workouts logged today', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)))
                      : Column(
                          children: workouts.map((w) => _WorkoutTile(workout: w)).toList(),
                        ),
                  loading: () => Center(child: Padding(
                    padding: EdgeInsets.all(12), child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary))),
                  error: (e, _) => Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                ),

                // Today's Meals
                const SizedBox(height: 14),
                Text("Today's Meals", style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                const SizedBox(height: 8),
                mealsAsync.when(
                  data: (meals) => meals.isEmpty
                      ? Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('No meals logged today', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)))
                      : Column(
                          children: meals.map((m) => _MealTile(meal: m)).toList(),
                        ),
                  loading: () => Center(child: Padding(
                    padding: EdgeInsets.all(12), child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary))),
                  error: (e, _) => Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                ),

                // Goals
                const SizedBox(height: 14),
                Text('Goals', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                const SizedBox(height: 8),
                goalsAsync.when(
                  data: (goals) => goals.isEmpty
                      ? Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text('No goals set', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)))
                      : Column(
                          children: goals.map((g) => _GoalTile(goal: g)).toList(),
                        ),
                  loading: () => Center(child: Padding(
                    padding: EdgeInsets.all(12), child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary))),
                  error: (e, _) => Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                ),

                // Submit feedback
                const SizedBox(height: 14),
                Text('Send Feedback', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _feedbackController,
                        decoration: const InputDecoration(
                          hintText: 'Write feedback for this member…',
                          filled: true,
                        ),
                        maxLines: 3,
                        style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: _submitFeedback,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayPrimary,
                            borderRadius: const BorderRadius.all(Radius.circular(10)),
                          ),
                          child: Text('Send Feedback',
                            textAlign: TextAlign.center,
                            style: ClayTokens.titleLarge.copyWith(fontSize: 15, color: ClayTokens.clayDarkTextPrimary, fontWeight: FontWeight.w600, letterSpacing: -0.24)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
          loading: () => Center(child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary)),
          error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary))),
        ),
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<Map<String, dynamic>> weights;

  const _WeightChart({required this.weights});

  @override
  Widget build(BuildContext context) {
    if (weights.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
        ),
        child: Center(child: Text('No weight data', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08))),
      );
    }

    final reversed = weights.reversed.toList();
    final maxW = reversed.map((w) => (w['weight_kg'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);
    final minW = reversed.map((w) => (w['weight_kg'] as num?)?.toDouble() ?? 0).reduce((a, b) => a < b ? a : b);
    final range = (maxW - minW).clamp(0.5, 100.0);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(reversed.length, (i) {
                final w = (reversed[i]['weight_kg'] as num?)?.toDouble() ?? 0;
                final pct = ((w - minW) / range).clamp(0.0, 1.0);
                final h = (pct * 54 + 6).clamp(6.0, 60.0);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => _showWeight(context, i, w),
                    child: Container(
                      height: h,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                        gradient: LinearGradient(
                          colors: [ClayTokens.clayPrimary, ClayTokens.clayPrimaryLight],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Text('${reversed.length} measurements · Tap bar for weight',
            style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
        ],
      ),
    );
  }

  void _showWeight(BuildContext context, int i, double w) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Entry ${i + 1}: ${w.toStringAsFixed(1)} kg'), duration: const Duration(seconds: 1)),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
      ),
      child: Center(child: CupertinoActivityIndicator(radius: 10, color: ClayTokens.clayPrimary)),
    );
  }
}

class _WorkoutTile extends StatelessWidget {
  final Map<String, dynamic> workout;
  const _WorkoutTile({required this.workout});

  @override
  Widget build(BuildContext context) {
    final name = workout['exercise_name'] as String? ?? 'Exercise';
    final sets = workout['sets'] as int?;
    final reps = workout['reps'] as int?;
    final weight = workout['weight_kg'] as double?;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(CupertinoIcons.person, color: ClayTokens.clayPrimary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(name, style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08))),
          if (sets != null)
            Text('$sets×$reps', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ClayTokens.clayPrimary, letterSpacing: -0.08)),
          if (weight != null) ...[
            const SizedBox(width: 4),
            Text('${weight}kg', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
          ],
        ],
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  final Map<String, dynamic> meal;
  const _MealTile({required this.meal});

  @override
  Widget build(BuildContext context) {
    final name = meal['food_name'] as String? ?? '';
    final calories = meal['calories'] as int?;
    final type = meal['meal_type'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: ClayTokens.clayWarning.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(CupertinoIcons.tray, color: ClayTokens.clayWarning, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08)),
                if (type.isNotEmpty)
                  Text(type[0].toUpperCase() + type.substring(1),
                    style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
              ],
            ),
          ),
          if (calories != null)
            Text('$calories kcal', style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w600, color: ClayTokens.clayWarning, letterSpacing: -0.08)),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final Map<String, dynamic> goal;
  const _GoalTile({required this.goal});

  @override
  Widget build(BuildContext context) {
    final title = goal['title'] as String? ?? '';
    final status = goal['status'] as String? ?? 'active';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(
            status == 'completed' ? CupertinoIcons.checkmark_circle : CupertinoIcons.flag,
            color: status == 'completed' ? ClayTokens.clayAccent : ClayTokens.clayWarning,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.08))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: status == 'completed'
                  ? ClayTokens.clayAccent.withAlpha(20)
                  : ClayTokens.clayWarning.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(status, style: ClayTokens.labelMedium.copyWith(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: status == 'completed' ? ClayTokens.clayAccent : ClayTokens.clayWarning,
              letterSpacing: -0.08,
            )),
          ),
        ],
      ),
    );
  }
}
