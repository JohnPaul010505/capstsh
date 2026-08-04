# Centered Popup Video Viewer + Instant Calendar (no loading)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal (user report):** "The video is just keep on loading" + "the calendar also it is just keep on loading. Show instant the display for the video and the calendar." Also: tapping "view" on the saved proof must **pop up centered** (no screen change).

**Root causes found:**
1. **Video:** the tile called `VideoPlayerController.initialize()` in `initState` and gated the UI on it. On web, proofs are MediaRecorder **.webm** files whose duration header is missing/Infinity, so the browser's `canplay` (which the plugin waits for) can stall → infinite spinner.
2. **Calendar:** the whole sheet was gated behind `entriesAsync.when(loading: spinner)` — the grid could not render until both Supabase queries returned (workouts + meals run serially).

**Fix strategy (verified against DB: proof URL serves 206, video/webm, 2.5MB):**
- Video: never block on `initialize()`. Saved strip is shown instantly; tapping it opens a centered dialog that calls `play()` immediately inside the user gesture (satisfies web autoplay), shows a spinner only briefly, and after 15s falls back to an explicit tap-to-play button (never an infinite spinner).
- Calendar: render the grid instantly with empty data; dots pop in when the fetch lands (tiny "syncing…" chip in the header). Parallelize the two queries with `Future.wait`.

**Tech Stack:** Flutter, video_player (web play-first), Supabase Dart client, Riverpod, ClayTokens, PressableCard.

**Branch:** `feature/workout-page-v2`.

**Verification baseline:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos OK); `flutter build web --release` → succeeds.

---

## Task 1: Centered popup video viewer (play-first, no infinite spinner)

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

- [x] **Step 1:** Tile no longer owns a controller; `videoUrl != null` → always render the saved strip (instant, no loading UI). Strip tap → `_showProofDialog()`.
- [x] **Step 2:** `_showProofDialog` uses `showGeneralDialog` (same screen): black barrier (dismissible), `FadeTransition` + `ScaleTransition` 0.9→1.0 with `Curves.easeOutBack` (pop feel), 320ms.
- [x] **Step 3:** `_ProofViewerDialog` (StatefulWidget): creates the controller, calls `_tryPlay()` immediately (user gesture), `initialize()` result is non-blocking; spinner only while `!_initialized && !_waitingForTap`.
- [x] **Step 4:** 15s `Timer`: if still not initialized and no error → `_waitingForTap = true` → centered play button; tapping plays again. `_error` → "Video unavailable". Card tap toggles play/pause.
- [x] **Step 5:** X button (top-right) closes via `Navigator.pop`; `dispose()` cancels timer + disposes controller. Red trash stays on the saved strip (not in the viewer).
- [x] **Step 6:** Deleted the old inline `_buildVideoCard`, `_stopAndCollapse`, `_togglePlay`, `_initVideo`, `_onVideoTick`, `_disposeVideo`, `_collapsed` state.

## Task 2: Instant calendar (no blocking spinner)

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
- Modify: `mobile/fitness_app/lib/features/member/calendar/providers/month_entries_provider.dart`

- [x] **Step 1:** Sheet always builds `FlipCard` from `entriesAsync.valueOrNull` (empty lists while loading) — the month grid renders instantly.
- [x] **Step 2:** Header shows a tiny 10px spinner + "syncing…" chip while loading; "couldn't sync" chip on error (non-blocking).
- [x] **Step 3:** `monthEntriesProvider` fetches workouts + meals in parallel via `Future.wait` (halves perceived load time).

## Task 3: Verify + commit

- [x] **Step 1:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos).
- [x] **Step 2:** `flutter build web --release` → succeeds.
- [ ] **Step 3 (manual, web — M002):** calendar opens instantly (grid first, dots soon after); tap "Video saved · tap to view" → centered popup pops in and video starts; X / outside tap closes; trash on strip still removes the proof.
- [ ] **Step 4:** Commit `fix(mobile): instant calendar + centered popup video viewer`.
