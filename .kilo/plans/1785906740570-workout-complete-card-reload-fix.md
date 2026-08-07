# Fix Workout Complete Card Reload Lock

## Problem
The summary card disappears properly after dismissal, but after same-day app restart `_loadCompletedSummary()` sets `sessionEnded: true`, which re-hides the add-exercise form and exercise list.

## Root Cause
`_loadCompletedSummary()` in `workout_session_provider.dart:208-214` forces `sessionEnded: true` when reloading persisted summary data from SharedPreferences. This was intended to make the card visible after restart, but it also re-locks the rest of the UI.

## Fix
Remove `sessionEnded: true` from the `_emitState()` call in `_loadCompletedSummary()`. The card visibility is already controlled by `completedToday` in `WorkoutPage`, so `sessionEnded` does not need to be set here.

## File to Change
`mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`

## Exact Change

### Before (lines 208-214)
```dart
_emitState(
  lastCompletedExercises: exercises,
  lastCompletedCalories: calories,
  lastCompletedElapsedSeconds: elapsed,
  completedAt: completedAt,
  sessionEnded: true, // Ensure summary card shows after restart
);
```

### After
```dart
_emitState(
  lastCompletedExercises: exercises,
  lastCompletedCalories: calories,
  lastCompletedElapsedSeconds: elapsed,
  completedAt: completedAt,
);
```

## Validation
- Run the app, complete a workout, dismiss the summary card, verify add form/exercise list reappear.
- Restart the app same day, verify summary card still appears and add form/exercise list remain visible.
- Change device date to next day, restart app, verify summary is cleared automatically.
