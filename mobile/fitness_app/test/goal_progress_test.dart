import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/features/shared/utils/goal_progress.dart';

/// Single source of truth for goal progress — the trainer Members list, the
/// member Goals screen, and the trainer Member Insight screen must all show
/// the SAME number for the same goal (the86% vs 20% bug).
void main() {
  group('computeGoalProgress — weight journey (goal_type set)', () {
    test('gain muscle: journey progress, not baseline/target ratio', () {
      // John Paul Hoquiton's exact scenario: baseline 60kg (stored
      // current_value), target 70kg, live weight 62kg. The member's own
      // Goals screen shows 20% ((62-60)/(70-60)); the trainer list used to
      // show 86% (60.2/70) — this asserts the member number wins.
      final r = computeGoalProgress(
        baseline: 60,
        target: 70,
        live: 62,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, closeTo(20.0, 0.001));
      expect(r.remaining, closeTo(8.0, 0.001));
    });

    test('gain muscle: uppercase goal type behaves identically', () {
      final r = computeGoalProgress(
        baseline: 60,
        target: 70,
        live: 62,
        goalType: 'GAIN MUSCLE',
      );
      expect(r.pct, closeTo(20.0, 0.001));
      expect(r.remaining, closeTo(8.0, 0.001));
    });

    test('gain muscle: overshoot clamps to 100 with 0 remaining', () {
      final r = computeGoalProgress(
        baseline: 60,
        target: 70,
        live: 71,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, 100.0);
      expect(r.remaining, 0.0);
    });

    test('gain muscle: below baseline clamps to 0, remaining keeps gap', () {
      final r = computeGoalProgress(
        baseline: 60,
        target: 70,
        live: 58,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, 0.0);
      expect(r.remaining, closeTo(12.0, 0.001));
    });

    test('lose weight: travels down from baseline to target', () {
      // baseline 80, target 70, live 75 → (80-75)/(80-70) = 50%.
      final r = computeGoalProgress(
        baseline: 80,
        target: 70,
        live: 75,
        goalType: 'Lose Weight',
      );
      expect(r.pct, closeTo(50.0, 0.001));
      expect(r.remaining, closeTo(5.0, 0.001));
    });

    test('lose weight: already past target clamps to 100', () {
      final r = computeGoalProgress(
        baseline: 80,
        target: 70,
        live: 68,
        goalType: 'Lose Weight',
      );
      expect(r.pct, 100.0);
      expect(r.remaining, 0.0);
    });

    test('baseline equals target: zero-length journey shows 0%', () {
      final r = computeGoalProgress(
        baseline: 70,
        target: 70,
        live: 62,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, 0.0);
      expect(r.remaining, closeTo(8.0, 0.001));
    });

    test('goal_type set but no live weight yet → legacy stored math', () {
      final r = computeGoalProgress(
        baseline: 60,
        target: 70,
        live: null,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, closeTo(60 / 70 * 100, 0.001));
      expect(r.remaining, closeTo(10.0, 0.001));
    });

    test('goal_type set but no baseline → no journey, 0%', () {
      final r = computeGoalProgress(
        baseline: null,
        target: 70,
        live: 62,
        goalType: 'Gain Muscle',
      );
      expect(r.pct, 0.0);
      expect(r.remaining, closeTo(70.0, 0.001));
    });
  });

  group('computeGoalProgress — legacy / seeded goals (no goal_type)', () {
    test('stored current/target ratio is authoritative for seeds', () {
      // Documents the OLD trainer formula surviving only for seed rows:
      //60.2/70 ≈ 86% — this is what showed instead of the20% journey.
      final r = computeGoalProgress(
        baseline: 60.2,
        target: 70,
        live: 62,
        goalType: '',
      );
      expect(r.pct, closeTo(60.2 / 70 * 100, 0.001));
      expect(r.remaining, closeTo(9.8, 0.001));
    });

    test('legacy over target clamps pct at 100, keeps raw remaining', () {
      final r = computeGoalProgress(
        baseline: 80,
        target: 70,
        live: null,
        goalType: '',
      );
      expect(r.pct, 100.0);
      expect(r.remaining, closeTo(-10.0, 0.001));
    });

    test('null baseline in legacy counts as 0', () {
      final r = computeGoalProgress(
        baseline: null,
        target: 70,
        live: null,
        goalType: '',
      );
      expect(r.pct, 0.0);
      expect(r.remaining, closeTo(70.0, 0.001));
    });

    test('missing target →0% and no remaining', () {
      final rNull = computeGoalProgress(baseline: 60, target: null, live: 62);
      expect(rNull.pct, 0.0);
      expect(rNull.remaining, isNull);

      final rZero = computeGoalProgress(baseline: 60, target: 0, live: 62);
      expect(rZero.pct, 0.0);
      expect(rZero.remaining, isNull);
    });
  });

  test('fraction is the clamped 0..1 view used by progress bars', () {
    final r = computeGoalProgress(
      baseline: 60,
      target: 70,
      live: 62,
      goalType: 'Gain Muscle',
    );
    expect(r.fraction, closeTo(0.2, 0.00001));
    expect(computeGoalProgress(baseline: 500, target: 70).fraction, 1.0);
    expect(computeGoalProgress(baseline: -5, target: 70).fraction, 0.0);
  });
}
