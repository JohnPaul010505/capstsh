# Workout Session Done-State + Calendar Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Fix the calendar's PH-day matching (UTC bug that hides today's workout and paints a dumbbell on Aug 31), switch weekday labels to Sun/Mon/Tue 3-char, rework the workout session flow so "Done" keeps the current session + summary card visible and offers a "New Session" restart, view proof videos in an in-place overlay (no route push), and replace the viewer's Remove button with a red trash icon on the video strip.

**Architecture:** All changes are Flutter-only (no DB/schema/migration changes). Calendar day-matching converts parsed UTC timestamps to local (PH) wall time via `.toLocal()` — consistent with the workout page's existing "full local day as UTC bounds" convention (device timezone = UTC+8). Session flow replaces the `_sessionResetAt` "hide finished exercises" filter with a `_sessionDone` flag that keeps everything visible; the summary card's button flips to "New Session". Video viewer becomes a `showGeneralDialog` overlay (full-screen by default in Flutter 3.44.6 — `RawDialogRoute` has no inset, so no `insetPadding` param needed; the `Dialog` widget is what insets, and we don't use it) so the workout screen stays in context; the proof-video Remove action moves onto the video strip as a red trash icon.

**Tech Stack:** Flutter, Riverpod, Supabase Dart client, video_player, ClayTokens.

**Branch:** `feature/workout-page-v2` (current). ⚠ `git status` showed uncommitted WIP overlapping Task 3/4 files (`workout_page.dart`, `exercise_proof_button.dart`) — committed as Task 0 so each plan task commits cleanly.

**Verification baseline:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos OK); `flutter build web --release` → succeeds. Camera flows stay device-only; web fallback covers the dev machine.

---

## Task 0: Commit current WIP baseline

- [x] **Step 1:** Review uncommitted changes (`git status --short`) — admin glassmorphism overhaul + mobile login/meals/trainer WIP + untracked calendar/camera/seed/plans.
- [x] **Step 2:** `git add -A; git commit -m "wip: admin glassmorphism overhaul, mobile login/meals/trainer WIP, calendar+camera features"` (908fc66).

## Task 1: Fix calendar PH-day matching (UTC → local)

**Root cause (verified in DB 2026-08-03):** the member's Aug-3 PH workout ("Pull ups", proof uploaded) is stored `2026-08-02T17:17:32Z` = Aug 3 01:17 AM PH. `month_entries_provider` correctly fetches PH-month bounds, but `month_day_grid.dart` and `_workoutsFor` match on the **raw UTC day**, so this row lands on Aug 2 (calendar "shows nothing" for Aug 3) and a Jul-31 test row (`2026-07-31T17:19:37Z` = Aug 1 01:19 AM PH, included in the August query window) paints a dumbbell on **Aug 31**. Fix: `.toLocal()` before day extraction.

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/month_day_grid.dart:46-55`
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart:63-70`

- [x] **Step 1:** `month_day_grid.dart` — `DateTime.tryParse(w['logged_at'] ...)` → `?.toLocal()` (workouts and meals grouping loops).
- [x] **Step 2:** `calendar_flip_sheet.dart` `_workoutsFor` — `DateTime.tryParse(...)` → `?.toLocal()`.
- [x] **Step 3:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos).
- [x] **Step 4:** Commit `fix(mobile): match calendar days by PH wall time instead of UTC` (9480196).

## Task 2: Weekday labels → Sun, Mon, Tue (3-char, Sunday-first grid)

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/month_day_grid.dart:44,122`

- [x] **Step 1:** `final leading = first.weekday - 1;` → `final leading = first.weekday % 7; // Sunday = 0 leading cells (PH Sunday-first grid)`
- [x] **Step 2:** `const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];` → `const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];`
- [x] **Step 3:** `flutter analyze --no-pub` (0 new issues) + `flutter build web --release` (succeeds).
- [x] **Step 4:** Commit `feat(mobile): Sunday-first calendar with 3-char weekday labels` (4e48b87).

## Task 3: Session done-state — keep session + summary card, "New Session" restart

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [x] **Step 1:** `DateTime? _sessionResetAt;` → `bool _sessionDone = false;`
- [x] **Step 2:** `_finishSession` → `_completeSession()` (sets `_sessionDone = true`, keeps everything) + `_startNewSession()` (old reset logic minus filter).
- [x] **Step 3:** `_checkVideos` — removed `_sessionResetAt` filter (checks all today's exercises).
- [x] **Step 4:** Display filter removed in `build()` and the `exercisesAsync.when(data:)` branch (`displayExercises = exercises`).
- [x] **Step 5:** Start button now clears `_showSummary`/`_sessionDone`/`_videoCheckPassed` when starting.
- [x] **Step 6:** Summary card block passes `sessionDone: _sessionDone`, `onDone: _sessionDone ? _startNewSession : _completeSession`.
- [x] **Step 7:** `_SessionSummaryCard` — new `sessionDone` prop; "SESSION DONE" chip next to title; bottom button `sessionDone ? 'New Session' : 'Done'`.
- [x] **Step 8:** `flutter analyze --no-pub` (0 new issues) + `flutter build web --release` (succeeds).
- [x] **Step 9:** Commit `feat(mobile): keep done session on screen with New Session restart` (f9e2799).

## Task 4: Proof video overlay viewer + red trash icon on the video strip

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

- [x] **Step 1:** `_openVideo` → `showGeneralDialog` (barrierColor black, full-screen `RawDialogRoute` — no `insetPadding` param exists in Flutter 3.44.6; removed from the call). 'retake' pops the dialog, then `_record()` runs.
- [x] **Step 2:** New `_confirmRemoveProof()` on the tile + red `Icons.delete_outline` (`0xFFFF453A`) GestureDetector at the right of `_buildVideoStrip` (inner recognizer wins the tap arena, so trash never opens the viewer). Deletes only the video + clears proof; exercise row stays.
- [x] **Step 3:** `_ProofViewerPage` → `_ProofViewerDialog` (Container instead of Scaffold); deleted `_confirmRemove` and the Remove button; viewer keeps Close + Re-record only.
- [x] **Step 4:** `flutter analyze --no-pub` (0 new issues) + `flutter build web --release` (succeeds).
- [x] **Step 5:** Commit `feat(mobile): overlay proof viewer and red trash icon on video strip` (904edbc).

## Task 5: End-to-end verification (manual, web — M002)

- [ ] **Step 1:** Run the member app on web (`flutter run -d chrome` in `mobile/fitness_app/`, or `run_chrome.bat`), login `M002` / `123456789`.
- [ ] **Step 2:** Workout tab → open calendar (tap the date pill):
  - Aug 3 cell shows the dumbbell icon (the 01:17 AM "Pull ups"); Aug 31 shows **no** dumbbell; Aug 1 keeps its dumbbell (3 workouts: 01:19 AM test + 12:40/12:50 seed)
  - Weekday labels read Sun, Mon, Tue, Wed, Thu, Fri, Sat and line up with the days (Aug 1 under Sat column)
  - Tap Aug 3 → flip "View Workout" → back face lists "Pull ups" with a **DONE** chip (proof exists)
- [ ] **Step 3:** Session flow: add an exercise (or use today's), Start Session → Finish Session → Check Videos (record a web proof via the camera screen — 30s minimum) → Done Workout Session → summary card appears.
  - Tap **Done** on the summary card → card stays with green "SESSION DONE" chip, exercises stay listed, button reads **New Session**
  - Tap **New Session** → timer resets to 00:00, summary + chip disappear, exercises remain listed, Start Session is enabled
- [ ] **Step 4:** Video strip: tap the film strip → fullscreen dark overlay opens **over the workout screen** (no route change; back button still exits). Tap Re-record → camera flow; Close → back to workout screen.
- [ ] **Step 5:** Red trash icon on the right of the video strip → confirm dialog → video deleted from storage, strip returns to "No video proof yet", DONE chip/missing-video state updates, exercise row remains.
- [ ] **Step 6:** Re-run `flutter analyze --no-pub` and `flutter build web --release` from `mobile/fitness_app/` — both clean.
- [ ] **Step 7:** Real-device spot check (deferred, optional): countdown → 30s auto-record → Keep/Retake still works from the overlay flow (same `ProofCameraScreen` route).
