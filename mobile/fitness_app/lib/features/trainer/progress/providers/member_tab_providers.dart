import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';

/// Reuse the shared [InsightRange] window value-type (see
/// member_insight_overview_provider.dart) so the four date windows all compare
/// by bounds.
class ProgressRange {
  final DateTime start;
  final DateTime end;
  const ProgressRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is ProgressRange &&
      other.start.isAtSameMomentAs(start) &&
      other.end.isAtSameMomentAs(end);

  @override
  int get hashCode =>
      Object.hash(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
}

/// Composite family key: which member + which window. Value-typed so the
/// Workouts / Nutrition / Check-ins providers each refetch independently when
/// their own tab moves its range.
class MemberRange {
  final String id;
  final ProgressRange range;
  const MemberRange(this.id, this.range);

  @override
  bool operator ==(Object other) =>
      other is MemberRange && other.id == id && other.range == range;

  @override
  int get hashCode => Object.hash(id, range);
}

/// One workout log row for the Workouts tab: the exercise the member did, how
/// long it took, the calories burned and the optional proof video URL.
class WorkoutRow {
  final String id;
  final String exercise;
  final String? workoutName;
  final int? durationSeconds;
  final int? durationMinutes;
  final int? calories;
  final String? proofUrl;
  final DateTime loggedAt;

  const WorkoutRow({
    required this.id,
    required this.exercise,
    this.workoutName,
    this.durationSeconds,
    this.durationMinutes,
    this.calories,
    this.proofUrl,
    required this.loggedAt,
  });

  /// Human duration, preferring seconds then falling back to minutes.
  String get durationLabel {
    if (durationSeconds != null && durationSeconds! > 0) {
      final m = durationSeconds! ~/ 60;
      final s = durationSeconds! % 60;
      return m > 0 ? '${m}m ${s}s' : '${s}s';
    }
    if (durationMinutes != null && durationMinutes! > 0) return '${durationMinutes}m';
    return '—';
  }
}

/// Completed `workout_logs` rows for one member inside [ProgressRange],
/// newest first. The Workouts tab pages over this list client-side.
final memberWorkoutsProvider = FutureProvider.autoDispose
    .family<List<WorkoutRow>, MemberRange>((ref, key) async {
      final client = SupabaseClientService().client;
      final rows = await client
          .from('workout_logs')
          .select(
            'id, exercise_name, workout_name, total_calories, '
            'duration_seconds, proof_url, logged_at',
          )
          .eq('member_id', key.id)
          .gte('logged_at', key.range.start.toUtc().toIso8601String())
          .lte('logged_at', key.range.end.toUtc().toIso8601String())
          .order('logged_at', ascending: false);

      return (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        return WorkoutRow(
          id: m['id'] as String,
          exercise: (m['exercise_name'] as String?)?.trim().isNotEmpty == true
              ? (m['exercise_name'] as String).trim()
              : 'Exercise',
          workoutName: (m['workout_name'] as String?)?.trim(),
          durationSeconds: (m['duration_seconds'] as num?)?.toInt(),
          calories: (m['total_calories'] as num?)?.toInt(),
          proofUrl: m['proof_url'] as String?,
          loggedAt: DateTime.parse(m['logged_at'] as String).toLocal(),
        );
      }).toList();
    });


// ---------------------------------------------------------------------------
// Nutrition
// ---------------------------------------------------------------------------

/// One `meal_logs` row: the food, meal slot, time, macros and optional photo.
class MealRow {
  final String id;
  final String foodName;
  final String mealType;
  final DateTime mealTime;
  final int calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final String? photoUrl;

  const MealRow({
    required this.id,
    required this.foodName,
    required this.mealType,
    required this.mealTime,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    this.photoUrl,
  });
}

/// Meal rows plus the range totals the donut re-sums whenever the window
/// changes.
class NutritionData {
  final List<MealRow> meals;
  final int totalKcal;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const NutritionData({
    required this.meals,
    required this.totalKcal,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });
}

/// `meal_logs` rows for one member inside [ProgressRange], newest first, with
/// the kcal + macro sums the Nutrition donut and legend display.
final memberNutritionProvider = FutureProvider.autoDispose
    .family<NutritionData, MemberRange>((ref, key) async {
      final client = SupabaseClientService().client;
      final rows = await client
          .from('meal_logs')
          .select(
            'id, food_name, meal_type, meal_time, calories, '
            'protein_g, carbs_g, fat_g, photo_url',
          )
          .eq('member_id', key.id)
          .gte('meal_time', key.range.start.toUtc().toIso8601String())
          .lte('meal_time', key.range.end.toUtc().toIso8601String())
          .order('meal_time', ascending: false);

      final meals = (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        return MealRow(
          id: m['id'] as String,
          foodName: (m['food_name'] as String?)?.trim().isNotEmpty == true
              ? (m['food_name'] as String).trim()
              : 'Meal',
          mealType: (m['meal_type'] as String?) ?? '',
          mealTime: DateTime.parse(m['meal_time'] as String).toLocal(),
          calories: (m['calories'] as num?)?.toInt() ?? 0,
          proteinG: (m['protein_g'] as num?)?.toDouble() ?? 0,
          carbsG: (m['carbs_g'] as num?)?.toDouble() ?? 0,
          fatG: (m['fat_g'] as num?)?.toDouble() ?? 0,
          photoUrl: m['photo_url'] as String?,
        );
      }).toList();

      return NutritionData(
        meals: meals,
        totalKcal: meals.fold(0, (s, m) => s + m.calories),
        proteinG: meals.fold(0.0, (s, m) => s + m.proteinG),
        carbsG: meals.fold(0.0, (s, m) => s + m.carbsG),
        fatG: meals.fold(0.0, (s, m) => s + m.fatG),
      );
    });

// ---------------------------------------------------------------------------
// Check-ins
// ---------------------------------------------------------------------------

/// One `attendance` row: when the member checked in and how.
class CheckinRow {
  final String id;
  final DateTime checkInTime;
  final String? entryMethod;

  const CheckinRow({
    required this.id,
    required this.checkInTime,
    this.entryMethod,
  });
}

/// `attendance` rows for one member inside [ProgressRange], newest first. The
/// Check-ins tab pages over this list client-side.
final memberCheckinsProvider = FutureProvider.autoDispose
    .family<List<CheckinRow>, MemberRange>((ref, key) async {
      final client = SupabaseClientService().client;
      final rows = await client
          .from('attendance')
          .select('id, check_in_time, entry_method')
          .eq('member_id', key.id)
          .gte('check_in_time', key.range.start.toUtc().toIso8601String())
          .lte('check_in_time', key.range.end.toUtc().toIso8601String())
          .order('check_in_time', ascending: false);

      return (rows as List).map((r) {
        final m = r as Map<String, dynamic>;
        return CheckinRow(
          id: m['id'] as String,
          checkInTime: DateTime.parse(m['check_in_time'] as String).toLocal(),
          entryMethod: (m['entry_method'] as String?)?.trim(),
        );
      }).toList();
    });
