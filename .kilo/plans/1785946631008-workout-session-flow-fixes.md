# Workout Session Flow Fixes

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

## Goal
Align the workout screen behavior with the user's desired flow:
1. Session numbering + titles: "Complete Workout" (S1), "Complete Workout S2" (S2), "Complete Workout S3" (S3)
2. "View Workout Cards" button is a one-time action (disappears after showing, not a toggle)
3. Previous session cards ordered oldest-first (S1 on top, then S2, then S3)
4. Calendar titles: "Workout", "Workout S2", "Workout S3" (already works)
5. Verify video proof auto-marks exercise done after 30s recording
6. Verify persistence across app restarts via `_loadSessionHistory`

## Verification baseline
`flutter analyze --no-pub` → 0 issues

---

## Task 1: Fix session summary titles

**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

The summary card title is currently:
- S1: `"Workout Complete"`
- S2: `"S2"`
- S3+: `"S3"`

Change to:
- S1: `"Complete Workout"`
- S2: `"Complete Workout S2"`
- S3+: `"Complete Workout S3"`

- [ ] **Step 1:** In `_buildSummary()` (around line 613), replace:
  ```dart
  final label = completed == 1
      ? 'Workout Complete'
      : 'S$completed';
  ```
  with:
  ```dart
  final label = completed == 1
      ? 'Complete Workout'
      : 'Complete Workout S$completed';
  ```

- [ ] **Step 2:** `flutter analyze --no-pub` → 0 issues.

---

## Task 2: Change "View Workout Cards" from toggle to one-time show

**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

Currently `_togglePreviousCards()` flips `_showPreviousCards` and the button text changes between "View Workout Cards" and "Hide Workout Cards". The user wants: when pressed, previous cards appear and the button disappears entirely. "New Session" stays visible.

- [ ] **Step 1:** Replace `_togglePreviousCards()` with a one-time show method:
  ```dart
  void _showPreviousCards() {
    if (!_showPreviousCards) {
      setState(() => _showPreviousCards = true);
    }
  }
  ```

- [ ] **Step 2:** In `_buildSummary()`, replace the `_togglePreviousCards` button with a conditional that only shows when `_showPreviousCards` is false:
  ```dart
  if (completed >= 2 && !_showPreviousCards)
    Container(
      // "View Workout Cards" button
      onPressed: _showPreviousCards,
      child: Text('View Workout Cards', ...),
    ),
  ```
  Remove the `_showPreviousCards ? 'Hide Workout Cards' : 'View Workout Cards'` toggle logic entirely.

- [ ] **Step 3:** Ensure `_showPreviousCards` is still reset to `false` in `startNewSession()` (already done at line 825).

- [ ] **Step 4:** `flutter analyze --no-pub` → 0 issues.

---

## Task 3: Fix previous session cards order (oldest first)

**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

In `_buildPreviousSessionCards()` (line 129), the list is reversed:
```dart
final reversed = session.completedSessions.reversed.toList();
```

This shows most-recent first (S2 above S1). The user wants oldest first (S1 on top, then S2, then S3).

- [ ] **Step 1:** Remove `.reversed`:
  ```dart
  final ordered = session.completedSessions.toList();
  ```
  And update the `.map()` to use `ordered` instead of `reversed`.

- [ ] **Step 2:** `flutter analyze --no-pub` → 0 issues.

---

## Task 4: Verify and fix previous session card titles

**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

In `_buildPreviousSessionCards()`, the title shows `s.workoutName` which is `"Workout S1"`, `"Workout S2"`, etc. The user wants the previous cards to display:
- S1: `"Complete Workout"`
- S2: `"Complete Workout S2"`
- S3: `"Complete Workout S3"`

- [ ] **Step 1:** Add a helper to compute the display label from a `CompletedSession`:
  ```dart
  String _sessionDisplayLabel(String workoutName, int index) {
    if (index == 0) return 'Complete Workout';
    return 'Complete Workout ${workoutName.split('S').last}';
  }
  ```
  Or compute from the session's position in the list.

- [ ] **Step 2:** In `_buildPreviousSessionCards()`, replace `s.workoutName` with the computed display label.

- [ ] **Step 3:** `flutter analyze --no-pub` → 0 issues.

---

## Task 5: Verify auto-mark-done after video recording

**Files:**
- `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`
- `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`

The user's desired flow: after 30s recording completes, the exercise is automatically marked done and the next exercise's record button appears.

- [ ] **Step 1:** Verify `exercise_proof_button.dart` lines 53-56 and 66-68 call `widget.onDone()` after `widget.onRecorded(url)`:
  ```dart
  widget.onRecorded(url);
  widget.onDone();
  ```
  This already exists. No change needed.

- [ ] **Step 2:** Verify `markDone()` in `workout_session_provider.dart` (line 367) correctly advances to the next exercise or calls `_finishSession()` for the last exercise. This already exists. No change needed.

- [ ] **Step 3:** Verify `canStartProof: session.isRunning && isCurrent` in `workout_page.dart` line 596 ensures proof recording is only available during an active session. This already exists. No change needed.

---

## Task 6: Verify calendar title mapping

**File:** `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`

- [ ] **Step 1:** Confirm line 350:
  ```dart
  final sessionName = entry.key == 'Workout S1' ? 'Workout' : entry.key;
  ```
  This already maps "Workout S1" → "Workout" and keeps "Workout S2", "Workout S3" as-is. No change needed.

---

## Task 7: Verify persistence across app restarts

**File:** `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`

`_loadSessionHistory()` (line 157) fetches today's `workout_logs` and rebuilds `completedSessions` on app start. This means calendar entries and session history persist across restarts.

- [ ] **Step 1:** Confirm `_loadSessionHistory` is called in the `WorkoutSessionNotifier` constructor (line 120). Already exists.

- [ ] **Step 2:** Note: after app restart, `sessionEnded` is `false` and `exercises` is empty, so the workout screen shows the "New Session" button rather than the last summary card. This is by design — the workout screen is for active sessions; the calendar is for viewing past sessions. If the user wants the summary card to persist on the workout screen after restart, that requires a separate enhancement to reconstruct `exercises` from `completedSessions` or show the last completed session's summary.

---

## Task 8: End-to-end verification

- [ ] **Step 1:** `flutter analyze --no-pub` from `mobile/fitness_app/` → 0 issues.
- [ ] **Step 2:** Manual web test (M002):
  1. Login → Workout tab
  2. Add 3 exercises → "Start Session"
  3. Record proof for each exercise (Ready? → Start → 3-2-1 → 30s record → auto-done)
  4. Verify summary card title is "Complete Workout" for S1
  5. Tap "New Session" → add exercises → complete S2
  6. Verify S2 title is "Complete Workout S2"
  7. Verify "View Workout Cards" button appears and disappears after tapping (not toggle)
  8. Verify S1 card appears above S2 card (oldest first)
  9. Complete S3 → verify title is "Complete Workout S3"
  10. Verify only "View Workout Cards" button is shown
  11. Tap "View Workout Cards" → verify S1, S2, S3 all appear in order (S1 on top)
  12. Open calendar → verify entries show "Workout", "Workout S2", "Workout S3"
- [ ] **Step 3:** Kill app, restart → verify calendar still shows today's entries (persistence works).
