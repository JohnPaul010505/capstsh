class WorkoutLog {
  final String id;
  final String memberId;
  final String exerciseName;
  final int? sets;
  final int? reps;
  final double? weightKg;
  final int? durationMinutes;
  final String? notes;
  final DateTime loggedAt;

  WorkoutLog({
    required this.id,
    required this.memberId,
    required this.exerciseName,
    this.sets,
    this.reps,
    this.weightKg,
    this.durationMinutes,
    this.notes,
    required this.loggedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
    id: json['id'] as String,
    memberId: json['member_id'] as String,
    exerciseName: json['exercise_name'] as String,
    sets: json['sets'] as int?,
    reps: json['reps'] as int?,
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    durationMinutes: json['duration_minutes'] as int?,
    notes: json['notes'] as String?,
    loggedAt: DateTime.parse(json['logged_at'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'member_id': memberId,
    'exercise_name': exerciseName,
    'sets': sets,
    'reps': reps,
    'weight_kg': weightKg,
    'duration_minutes': durationMinutes,
    'notes': notes,
    'logged_at': loggedAt.toIso8601String(),
  };
}
