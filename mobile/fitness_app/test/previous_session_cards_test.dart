import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:fitness_app/features/member/workout/pages/workout_page.dart';
import 'package:fitness_app/features/member/workout/providers/workout_session_provider.dart';
import 'package:fitness_app/features/shared/widgets/glass_card.dart';

void main() {
  testWidgets(
    'previous summaries use the member card surface and 3px gaps in light mode',
    (tester) async {
      ClayColors.setBrightness(Brightness.light);
      addTearDown(() => ClayColors.setBrightness(Brightness.dark));
      final saved = CompletedSession(
        workoutName: 'Workout S1',
        exerciseNames: ['Bench Press'],
        exerciseCalories: [5],
        exerciseProofUrls: ['https://example.invalid/proof.mp4'],
        totalCalories: 5,
        elapsedSeconds: 41,
        restSeconds: 10,
        completedAt: DateTime(2026, 10, 23),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PreviousSessionCards(
                session: WorkoutSessionState(
                  completedSessions: [saved, saved, saved],
                ),
                showCompletionMessage: false,
                onViewProof: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MemberGlassCard), findsNWidgets(2));
      expect(find.text('View Video'), findsNWidgets(2));
      final cards = find.byType(MemberGlassCard);
      expect(
        tester.getTopLeft(cards.at(1)).dy -
            tester.getBottomLeft(cards.at(0)).dy,
        3,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
