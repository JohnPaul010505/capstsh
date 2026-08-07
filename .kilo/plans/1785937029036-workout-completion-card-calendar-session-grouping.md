# Workout Completion Card + Calendar Session Grouping

## Goal
1. Show a completion card after each workout session with the correct title:
   - 1st completed session → **"Workout Complete"**
   - 2nd completed session → **"S2"**
   - 3rd completed session → **"S3"**
2. In the calendar back-face, group exercises by session and display total kcal per session.

## Context
- `WorkoutSessionState.sessionCount` tracks **started** sessions (incremented in `startNewSession()`), not completed ones. The current summary label at `workout_page.dart:540` is therefore off-by-one for the first session.
- `persistSession()` writes individual exercises to `workout_logs` with a shared `workout_name` (e.g. `Workout S1`), but does **not** store total calories.
- The calendar (`calendar_flip_sheet.dart`) currently renders a flat `ListView` of `_WorkoutCard` items with no session grouping and no kcal display.

## Decisions
- **Completed-count based titles**: Use a new `completedSessionCount` field on `WorkoutSessionState` that increments only in `_finishSession()`.
- **Store kcal in DB**: Add `total_calories` (`integer`) to the `workout_logs` table and populate it during `persistSession()`. On-the-fly calculation is not viable because MET values are not stored in `workout_logs`.
- **Calendar grouping**: Group calendar entries by `workout_name` and render a session header (title + total kcal) above the exercise list.

## Implementation Tasks

### 1. Track completed sessions
**File:** `lib/features/member/workout/providers/workout_session_provider.dart`
- Add `final int completedSessionCount;` to `WorkoutSessionState` (default `0`).
- In `_finishSession()`, set `completedSessionCount: state.completedSessionCount + 1`.
- Update `_copyWith` to accept and forward `completedSessionCount`.

### 2. Update completion card title
**File:** `lib/features/member/workout/pages/workout_page.dart`
- Replace the label logic at line 540-542:
  ```dart
  final completed = session.completedSessionCount;
  final label = completed == 1
      ? 'Workout Complete'
      : 'S$completed';
  ```

### 3. Persist total calories
**File:** `lib/shared/models/workout_log.dart`
- Add `final int? totalCalories;` and include it in `fromJson` / `toJson`.

**File:** `lib/features/member/workout/providers/workout_session_provider.dart`
- In `persistSession()`, compute `totalCalories` from the same fold used in `_finishSession()` and attach it to each `WorkoutLog`.

**Database:** `workout_logs` table
- Add column `total_calories integer NULL`.

**File:** `lib/features/member/calendar/providers/month_entries_provider.dart`
- Include `total_calories` in the `workout_logs` select query.

### 4. Group calendar by session with kcal
**File:** `lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
- In `_BackFace.build`, group `workouts` by `workout_name`.
- For each session group, render:
  - A session header row showing the workout name and summed `total_calories` (e.g. `"Workout S1 · 245 kcal"`).
  - The existing `_WorkoutCard` list for exercises in that session.
- Add a visual separator (e.g. `SizedBox(height: 12)` or a divider) between session groups.

### 5. Validation
- Run `flutter analyze` and fix any type errors.
- Manually verify:
  - First completed session shows **"Workout Complete"**.
  - Second completed session shows **"S2"**.
  - Third completed session shows **"S3"**.
  - Calendar back-face groups exercises under session headers with kcal totals.
  - Existing "Save" / "New Session" flow still works.

## Risks / Notes
- The first session previously had `sessionCount == 0` at completion, so its stored `workout_name` was `Workout S0`. After this change, `workout_name` remains tied to `sessionCount` (started count) and is not changed; only the **card title** uses `completedSessionCount`. Existing rows in `workout_logs` are unaffected.
- If the member restarts via idle (`_forceRestart`), `completedSessionCount` is **not** incremented, which is correct because no session was finished.
- `monthEntriesProvider` fetches all workouts for the month; grouping by `workout_name` is safe because `persistSession()` sets a consistent name per session.
