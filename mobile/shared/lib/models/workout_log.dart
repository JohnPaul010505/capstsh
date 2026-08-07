class WorkoutLog {
  final String id;
  final String memberId;
  final String exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final String? workoutName;
  final int? durationMinutes;
  final int? durationSeconds;
  final int? totalCalories;
  final String? notes;
  final String? proofUrl;
  final String? proofType;
  final DateTime loggedAt;

  WorkoutLog({
    required this.id,
    required this.memberId,
    required this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.durationMinutes,
    this.durationSeconds,
    this.totalCalories,
    this.notes,
    this.proofUrl,
    this.proofType,
    this.workoutName,
    required this.loggedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    exerciseName: json['exercise_name'] as String,
    workoutName: json['workout_name'] as String?,
    sets: json['sets'] as int?,
    reps: json['reps'] as int?,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    durationMinutes: json['duration_minutes'] as int?,
    durationSeconds: json['duration_seconds'] as int?,
    totalCalories: json['total_calories'] as int?,
    notes: json['notes'] as String?,
    proofUrl: json['proof_url'] as String?,
    proofType: json['proof_type'] as String?,
    loggedAt: DateTime.parse(json['logged_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    if (id.isNotEmpty) 'id': id,
    'member_id': memberId,
    'exercise_name': exerciseName,
    'workout_name': workoutName,
    'sets': sets,
    'reps': reps,
    'weight_kg': weightKg,
    'duration_minutes': durationMinutes,
    'duration_seconds': durationSeconds,
    'total_calories': totalCalories,
    'notes': notes,
    'proof_url': proofUrl,
    'proof_type': proofType,
    'logged_at': loggedAt.toIso8601String(),
  };
}
