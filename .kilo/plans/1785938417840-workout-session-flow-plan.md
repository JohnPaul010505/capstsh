# Workout Session Flow: Completion Cards, Session Grouping & Calendar Integration

## Goal
Implement the full workout session flow with stacked completion cards, session history persistence, and calendar integration matching the user's desired UX.

## Current State Summary
- Exercises can be added and sessions started
- Proof camera works (3-2-1 countdown, 30s auto-record) but shows preview screen requiring manual "Keep" tap
- Completion card shows "Workout Complete" / "S2" / "S3" based on `completedSessionCount`
- Calendar groups exercises by `workout_name` with kcal totals
- Session state is in-memory only; no persistence across app restarts

## Desired Flow
1. Member adds exercises, taps **Start Session**
2. For each exercise: taps **Record Proof** → Ready? → Start → 3-2-1 countdown → 30s auto-record → **auto-upload and return to workout screen** → exercise auto-marked **Done** → next exercise shows Record Proof
3. After all exercises done: **completion card** with session title, duration, kcal
4. Buttons after completion:
   - S1: **"New Session"** only
   - S2: **"New Session"** + **"View Workout Cards"**
   - S3: **"View Workout Cards"** only
5. **"View Workout Cards"** toggles previous session cards visible above current summary
6. Calendar shows grouped sessions: **"Workout"**, **"Workout S2"**, **"Workout S3"**

## Implementation Tasks

### Task 1: Fix proof camera auto-return after 30s
**File:** `mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart`
- Change `_ProofStage` enum: remove `preview`, keep `uploading`
- In `_stopRecording()`: after saving `_tempPath`, set stage to `uploading` and call `_keep()` directly
- In `_keep()`: after successful upload, `Navigator.pop(url)` to return URL
- In `build()`: replace preview controls with uploading spinner
- Remove `_preview` field, `_buildPreviewControls()`, `_retake()`, and `video_player` import
- Add `PopScope(canPop: _stage != _ProofStage.uploading)` to prevent back-navigation during upload
- On upload error: show error stage with Close button

### Task 2: Auto-mark exercise done after proof recorded
**File:** `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`
- In `_record()` (native) and `_recordWeb()` (web): after `widget.onRecorded(url)`, also call `widget.onDone()`
- This auto-advances the exercise to Done state and triggers next exercise proof flow

### Task 3: Add session history model and state
**File:** `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
- Add `CompletedSession` class:
  ```dart
  class CompletedSession {
    final String workoutName;
    final List<String> exerciseNames;
    final int totalCalories;
    final int elapsedSeconds;
    final DateTime completedAt;
    const CompletedSession({required this.workoutName, required this.exerciseNames, required this.totalCalories, required this.elapsedSeconds, required this.completedAt});
  }
  ```
- Add to `WorkoutSessionState`:
  - `final List<CompletedSession> completedSessions;`
  - `final bool showPreviousCards;`
- Update constructor defaults: `completedSessions = const []`, `showPreviousCards = false`
- Update `_copyWith` to include both new fields
- Update all existing `WorkoutSessionState` constructors throughout the file to pass the new fields

### Task 4: Load session history from DB on app init
**File:** `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
- Add `_loadSessionHistory()` async method called in constructor after `_loadWeight()`
- Query today's `workout_logs` for current user, selecting: `workout_name, exercise_name, total_calories, duration_seconds, logged_at`
- Group results by `workout_name`
- For each group, create a `CompletedSession` with aggregated kcal, seconds, and exercise names
- Compute max session number from `workout_name` regex (`S(\d+)`)
- Set state: `sessionCount = maxName`, `completedSessionCount = sessions.length`, `completedSessions = sessions`
- Wrap in try/catch, silent failure

### Task 5: Update _finishSession to append to history
**File:** `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
- In `_finishSession()`, create a `CompletedSession` from current exercises
- Append it to `state.completedSessions` when setting new state
- Also update the `.then()` callback to preserve `completedSessions`

### Task 6: Update completion card buttons per session count
**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
- After S1 (`completed == 1`): show only "New Session" button
- After S2 (`completed == 2`): show "New Session" + "View Workout Cards"
- After S3+ (`completed >= 3`): show only "View Workout Cards"
- Update `_buildSummary` method to return different button layouts based on `session.completedSessionCount`
- Ensure "New Session" resets `_showPreviousCards = false`

### Task 7: Add "View Workout Cards" toggle and previous session cards
**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
- Add `bool _showPreviousCards = false` to `_WorkoutPageState`
- Add `_togglePreviousCards()` method
- Add `_buildPreviousSessionCards()` widget that renders `session.completedSessions` in reverse order (newest first)
- Each previous card shows: workout name, exercise list, duration, total kcal
- Render previous cards between header and current summary when `session.sessionEnded && _showPreviousCards`
- "View Workout Cards" button text toggles to "Hide Workout Cards" when visible

### Task 8: Update calendar title mapping
**File:** `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
- In `_buildSessionGroups()`, map session header:
  - `Workout S1` → `Workout`
  - `Workout S2` → `Workout S2`
  - `Workout S3` → `Workout S3`
  - Others: keep as-is

### Task 9: Validation
- Run `flutter analyze` in `mobile/fitness_app` and `mobile/shared`
- Verify no errors or warnings in modified files
- Test flow:
  1. Add exercises, start session
  2. Record proof for each exercise (auto-return, auto-done)
  3. Complete session → correct title and buttons
  4. Start new session, complete → S2 title and both buttons
  5. Toggle "View Workout Cards" → previous cards appear
  6. Calendar flip sheet shows correct session names
  7. App restart preserves session history

## Files Modified
1. `mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart`
2. `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`
3. `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
4. `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
5. `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`

## Risks & Edge Cases
- **Race condition in `_finishSession`**: state updates in `.then()` callback could conflict with other state changes. Mitigate by only updating `lastPersistSuccess` in callback.
- **Session history on app restart**: if DB query fails or returns partial data, state may be inconsistent. Silent failure acceptable; user can continue workout.
- **Exercise auto-done**: if `onDone()` is called but user removes exercise immediately, state could be invalid. Current `removeExercise` guard checks `isRunning || sessionEnded` which protects against this.
- **Calendar grouping**: `workout_name` must be consistent between in-memory and persisted state. Current naming `Workout S${sessionCount}` is preserved.
