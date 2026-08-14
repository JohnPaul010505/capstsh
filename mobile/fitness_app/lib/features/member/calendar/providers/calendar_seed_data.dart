import 'dart:math';

class CalendarSeedData {
  static final Random _rand = Random(42);
  static const _exercises = [
    'Push-ups', 'Squats', 'Lunges', 'Plank', 'Burpees',
    'Jump Rope', 'Mountain Climbers', 'Sit-ups', 'Wall Sit', 'Bicep Curls',
  ];

  static List<Map<String, dynamic>> generateAug14Attendance(String userId) {
    final checkIn = DateTime(2026, 8, 14, 9, 0);
    final checkOut = checkIn.add(const Duration(hours: 1, minutes: 30));
    return [
      {
        'member_id': userId,
        'check_in_time': checkIn.toUtc().toIso8601String(),
        'check_in_date': checkIn.toIso8601String().split('T').first,
        'check_out_time': checkOut.toUtc().toIso8601String(),
        'expires_at': checkOut.add(const Duration(days: 1)).toUtc().toIso8601String(),
      }
    ];
  }

  static List<Map<String, dynamic>> generateAug14Measurement(String userId) {
    return [
      {
        'member_id': userId,
        'weight_kg': 72.5,
        'measured_at': DateTime(2026, 8, 14, 8, 30).toUtc().toIso8601String(),
      }
    ];
  }

  static List<Map<String, dynamic>> generateAug14Workouts(String userId) {
    final records = <Map<String, dynamic>>[];
    final baseTime = DateTime(2026, 8, 14, 10, 0);
    for (var s = 1; s <= 2; s++) {
      final workoutName = 'Workout S$s';
      for (var e = 0; e < 4; e++) {
        final exerciseName = _exercises[_rand.nextInt(_exercises.length)];
        final loggedAt = baseTime.add(Duration(minutes: e * 10));
        records.add({
          'member_id': userId,
          'workout_name': workoutName,
          'exercise_name': exerciseName,
          'logged_at': loggedAt.toUtc().toIso8601String(),
          'sets': 3,
          'reps': 12,
          'duration_seconds': 45,
          'total_calories': 120,
          'proof_url': 'https://example.com/proof/$userId/8/14/$s/$e.mp4',
        });
      }
    }
    return records;
  }
}
