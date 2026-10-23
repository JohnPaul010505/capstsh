import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fitness_app/features/member/workout/widgets/session_metrics.dart';
import 'package:fitness_app/features/member/workout/providers/workout_session_provider.dart';

void main() {
  testWidgets('summary fits duration, break and calories on a narrow phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 260,
            child: SessionMetrics(
              elapsedSeconds: 180,
              restSeconds: 45,
              calories: 12,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Break Time'), findsOneWidget);
    expect(find.text('00:00:45'), findsOneWidget);
    expect(find.text('00:03:00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('completed sessions preserve break time when restored', () {
    final json = {
      'workoutName': 'Workout',
      'exerciseNames': <String>[],
      'exerciseCalories': <int>[],
      'exerciseProofUrls': <String>[],
      'totalCalories': 12,
      'elapsedSeconds': 180,
      'restSeconds': 45,
      'completedAt': '2026-10-23T12:00:00',
    };
    expect(CompletedSession.fromJson(json).toJson()['restSeconds'], 45);
    json.remove('restSeconds');
    expect(CompletedSession.fromJson(json).toJson()['restSeconds'], 0);
  });
}
