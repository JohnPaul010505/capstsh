# New Session Button, Session Naming, Calendar Labels, and Duration Fix

## Changes Required

### Files Modified
1. `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
2. `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
3. `mobile/shared/lib/models/workout_log.dart`
4. `mobile/fitness_app/lib/features/member/calendar/providers/month_entries_provider.dart`
5. `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`

## 1. Session Exercise Duration (`SessionExercise` + display)

**Goal:** Show cumulative session time at the moment each exercise was marked done, formatted as `HH:MM:SS`.

### Changes
- **`SessionExercise`** (`workout_session_provider.dart`): Add `int? sessionElapsedSeconds` field.
- **`markDone()`**: Set `e.sessionElapsedSeconds = state.elapsedSeconds` before calling `_finishSession()`.
- **`toJson()` / `fromJson()`**: Include `sessionElapsedSeconds` so it survives SharedPreferences reload.
- **`workout_page.dart`**: Replace `_formatDuration(e.startedAt, e.doneAt)` with `_format(e.sessionElapsedSeconds ?? 0)`.

## 2. Remove Dismiss Button + Add "New Session" Button

**Goal:** Summary card stays persistent; user starts fresh sessions via a button.

### Changes
- **`workout_page.dart:_buildCompletedSummary`**: Remove the `GestureDetector` close icon (line ~538). Add a "New Session" button below the summary content that calls `notifier.startNewSession()`.
- Hide the button when `session.sessionCount >= 3` (max sessions reached).

## 3. `startNewSession()` in Provider

**Goal:** Start a fresh session while keeping `lastCompletedExercises`, `completedAt`, and `lastCompletedElapsedSeconds` so the summary card remains visible.

### Changes
- **`workout_session_provider.dart`**: Add `startNewSession()` method:
  - Guard: if `state.sessionCount >= 3`, show error / no-op (max 3 sessions).
  - Cancel ticker/idle timers.
  - Emit state with `exercises: const []`, `sessionEnded: false`, `sessionCount: state.sessionCount + 1`, preserving all `lastCompleted*` and `completedAt` fields.
  - Also reset `isRunning`, `elapsedSeconds`, `startedAt`, `idleWarning`, etc.

## 4. Session Naming in Summary Card

**Goal:** Show "Workout Complete" for session 1, "Workout Complete S2" for session 2, "Workout Complete S3" for session 3.

### Changes
- **`workout_page.dart:_buildCompletedSummary`**: Replace static `'Workout Complete'` text with a computed label:
  ```dart
  final label = session.sessionCount == 1
      ? 'Workout Complete'
      : 'Workout Complete S${session.sessionCount}';
  ```
  Note: `sessionCount` at this point reflects the session that just finished (it was incremented by `_finishSession`/`_forceRestart` before the card renders).

## 5. Calendar Workout Names (requires DB migration)

**Goal:** Calendar shows "Workout 1", "Workout S2", "Workout S3" so members can distinguish sessions.

### Database Migration (manual step, not in code)
- Add `workout_name` column (text, nullable) to the `workout_logs` table in Supabase.

### Model + Query Changes
- **`WorkoutLog` model**: Add `final String? workoutName;` field + factory/toJson updates.
- **`month_entries_provider.dart`**: Query `workout_name` in addition to existing fields.
- **`workout_session_provider.dart:persistSession()`**: Set `workoutName` on each `WorkoutLog`:
  ```dart
  workoutName: 'Workout ${state.sessionCount == 1 ? '1' : 'S${state.sessionCount}'}',
  ```
- **`calendar_flip_sheet.dart:_BackFace`**: Group `workouts` by `workout_name` and render each session as a labeled block (session name header + exercise list). If `workout_name` is null (legacy rows), fall back to "Workout".

## 6. Max 3-Session Guard

**Goal:** Prevent starting a 4th session.

### Changes
- **`workout_session_provider.dart:startNewSession()`**: Early return if `sessionCount >= 3`.
- **`workout_page.dart`**: Disable/hide the "New Session" button when `session.sessionCount >= 3`.
- Keep existing `PopScope` behavior: after 3 sessions, allow leaving the page; before 3, show warning.

## Validation Checklist
- Complete workout → summary card shows without X button.
- Tap "New Session" → card remains, add form reappears, `sessionCount` increments.
- Complete 2nd session → card title shows "Workout Complete S2".
- Tap "New Session" again → 3rd session starts.
- Complete 3rd session → card title shows "Workout Complete S3".
- "New Session" button is hidden/disabled after 3 sessions.
- Restart app same day → summary card visible, add form visible, card title correct.
- Change device date → summary auto-clears on load.
- Calendar flip sheet shows "Workout 1", "Workout S2", "Workout S3" grouped headers above each session's exercises.
- Exercise durations in summary show `HH:MM:SS` matching session elapsed time at completion.
