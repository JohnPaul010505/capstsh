# Plan: Move "New Session" button inside completed summary card

## Problem
After completing a session, the "New Session" button appears below the completed summary card. Pressing it hides the card and shows the add-exercise form. The user wants the button **inside** the card so the summary persists across sessions, up to the 3-session limit.

## Root Cause
1. `_finishSession()` async callback clears `completedAt` after persist, making `completedToday` false and hiding the card
2. Completed summary gated by `!_showAddForm`, so it hides when the add form is shown
3. Bottom `_buildBottomNewSessionButton` exists outside the card
4. `_buildExerciseList` initial button shows when exercises are empty and session is idle, potentially duplicating the card button

## Changes

### `workout_session_provider.dart`

**In `_finishSession()` async `persistSession().then()` callback (around line 415):**
- Remove `completedAt: null` from the `_emitState` call
- Keep `exercises: []` to clear exercises after persist
- This preserves `completedAt` so `completedToday` stays `true` and the card survives across app restarts (via `_saveCompletedSummary()` prefs)

### `workout_page.dart`

**1. In `_buildCompletedSummary` (around line 747):**
- Add a "New Session" button at the bottom of the card when `session.sessionCount < 3`
- Button style: same gradient as existing New Session buttons
- Button label: `sessionCount < 2 ? 'New Session' : 'New Session ($sessionCount/3)'`
- Button onPressed: `notifier.startNewSession()` then `setState(() => _showAddForm = true)`
- This makes the button part of the card itself

**2. In `build` method (line 167):**
- Change `if (session.completedToday && !_showAddForm)` to `if (session.completedToday)`
- This keeps the card visible even when the add form is shown

**3. In `build` method (lines 174-175):**
- Remove the bottom `_buildBottomNewSessionButton` entirely
- The button now lives inside the card

**4. In `_buildExerciseList` (line 485):**
- Change condition from `session.exercises.isEmpty && !session.isRunning && !session.sessionEnded`
- To: `session.exercises.isEmpty && !session.isRunning && !session.sessionEnded && !session.completedToday`
- This prevents the initial empty-state button from appearing when the completed summary card is visible

## Flow After Changes

1. **Session 1 ends:** `completedAt` preserved → card visible with "New Session" button inside
2. **Press "New Session":** `startNewSession()` increments `sessionCount` to 2, `_showAddForm = true` → add form appears, card stays
3. **Session 2 ends:** card visible with "New Session (2/3)" button
4. **Press "New Session":** `sessionCount` increments to 3, add form appears, card stays
5. **Session 3 ends:** card visible, but `sessionCount < 3` is false → no button rendered

## Validation
- Run `flutter analyze lib/features/member/workout/pages/workout_page.dart`
- Run `flutter analyze lib/features/member/workout/providers/workout_session_provider.dart`
- Verify: `_finishSession()` no longer sets `completedAt: null`
