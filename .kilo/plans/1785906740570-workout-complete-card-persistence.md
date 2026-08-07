# Fix Workout Complete Card Persistence

## Problem
After finishing a workout, the "Workout Complete" summary card disappears when dismissed, and the screen becomes blank because `sessionEnded` remains `true`, which hides the add-exercise form and exercise list.

## Root Cause
In `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`, `clearCompletedSummary()` clears the summary data but leaves `sessionEnded: true`. The `WorkoutPage` build method hides interactive content whenever `sessionEnded` is true.

## Fix
1. Update `clearCompletedSummary()` to preserve summary data and reset `sessionEnded` to `false`.
2. Update `_loadCompletedSummary()` to not force `sessionEnded: true` on reload, so the UI remains usable after restart.

## Files to Change
- `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`

## Exact Changes

### Change 1: `clearCompletedSummary()`

#### Before
```dart
void clearCompletedSummary() {
  _emitState(
    exercises: [...state.exercises],
    isRunning: state.isRunning,
    elapsedSeconds: state.elapsedSeconds,
    startedAt: state.startedAt,
    lastInteractionAt: state.lastInteractionAt,
    idleWarning: state.idleWarning,
    idleWarningSeconds: state.idleWarningSeconds,
    sessionEnded: state.sessionEnded,
    lastCompletedExercises: const [],
    lastCompletedCalories: 0,
    lastCompletedElapsedSeconds: 0,
    completedAt: null,
  );
  _clearCompletedPrefs();
}
```

#### After
```dart
void clearCompletedSummary() {
  _emitState(
    exercises: const [],
    isRunning: false,
    elapsedSeconds: 0,
    startedAt: null,
    lastInteractionAt: _stampInteraction(),
    idleWarning: false,
    idleWarningSeconds: 0,
    sessionEnded: false,
    lastCompletedExercises: state.lastCompletedExercises,
    lastCompletedCalories: state.lastCompletedCalories,
    lastCompletedElapsedSeconds: state.lastCompletedElapsedSeconds,
    completedAt: state.completedAt,
  );
}
```

### Change 2: `_loadCompletedSummary()`

#### Before
```dart
_emitState(
  lastCompletedExercises: exercises,
  lastCompletedCalories: calories,
  lastCompletedElapsedSeconds: elapsed,
  completedAt: completedAt,
  sessionEnded: true, // Ensure summary card shows after restart
);
```

#### After
```dart
_emitState(
  lastCompletedExercises: exercises,
  lastCompletedCalories: calories,
  lastCompletedElapsedSeconds: elapsed,
  completedAt: completedAt,
);
```

## Expected Behavior
1. User finishes a workout → "Workout Complete" card appears with summary.
2. User taps X to dismiss the card → summary data is preserved, card is hidden, add-exercise form and list reappear.
3. User can start a new session.
4. If app is restarted later the same day → `_loadCompletedSummary()` reloads the summary from SharedPreferences and card is visible again.
5. On next day → `_loadCompletedSummary()` detects stale date and clears automatically.

## Validation
- Run the app, complete a workout, dismiss the summary card, verify the add form/exercise list reappear.
- Restart the app same day, verify summary card still appears.
- Change device date to next day, restart app, verify summary is cleared.
