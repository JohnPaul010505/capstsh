/// Single source of truth for goal progress math.
///
/// The same goal used to show **86% on the trainer side** (`current_value /
/// target_value`, i.e. how big the starting weight is relative to the goal)
/// and **20% on the member's Goals screen** (journey progress: how far the
/// live weight has travelled from baseline to target). One formula lives
/// here; the member Goals screen, the trainer Members list, and the trainer
/// Member Insight screen all call it, so the numbers can never disagree
/// again.
///
/// Two modes, matching the member GoalCard rules exactly:
/// * **Weight journey** (goal has a `goal_type`, live weight and baseline
///   both known): progress = distance travelled across the baseline→target
///   range. `Lose Weight` travels down, everything else travels up.
/// * **Legacy / seeded goals** (no goal_type, or live weight/baseline not
///   available): the stored `current_value / target_value` ratio is
///   authoritative, so old rows keep the numbers they always showed.
class GoalProgress {
  /// Progress in percent, clamped to `0..100`.
  final double pct;

  /// Units still to go before the target (raw; may be negative on legacy
  /// overshoot — callers clamp for display, matching the member GoalCard).
  final double? remaining;

  const GoalProgress({required this.pct, required this.remaining});

  /// The `0..1` view used directly as a progress-bar value.
  double get fraction => (pct / 100.0).clamp(0.0, 1.0);
}

/// Computes goal progress from a stored goal row.
///
/// * [baseline] — the goal's stored `current_value` (weight when created).
/// * [target] — the goal's `target_value`.
/// * [live] — the member's latest body-measurement weight, if known.
/// * [goalType] — the goal's `goal_type` (`'Gain Muscle'`, `'Lose Weight'`,
///   …); empty string selects legacy math.
GoalProgress computeGoalProgress({
  double? baseline,
  double? target,
  double? live,
  String goalType = '',
}) {
  if (target == null || target <= 0) {
    return const GoalProgress(pct: 0, remaining: null);
  }

  final normalizedType = goalType.trim().toLowerCase();

  if (goalType.trim().isNotEmpty && live != null && baseline != null) {
    // Weight-journey mode: measure travel across [low, high] regardless of
    // whether the goal is to go up or down.
    final low = baseline < target ? baseline : target;
    final high = baseline < target ? target : baseline;
    final double pct;
    if (high == low) {
      pct = 0.0;
    } else {
      final travelled =
          normalizedType == 'lose weight' ? high - live : live - low;
      pct = (travelled / (high - low) * 100.0).clamp(0.0, 100.0);
    }

    final double remaining;
    if (normalizedType == 'gain muscle') {
      remaining = (target - live).clamp(0.0, double.infinity);
    } else if (normalizedType == 'lose weight') {
      remaining = (live - target).clamp(0.0, double.infinity);
    } else {
      remaining = (target - live).abs();
    }
    return GoalProgress(pct: pct, remaining: remaining);
  }

  // Legacy / seeded goals: stored current_value is authoritative.
  final current = baseline ?? 0;
  final pct = (current / target * 100.0).clamp(0.0, 100.0);
  return GoalProgress(pct: pct, remaining: target - current);
}
