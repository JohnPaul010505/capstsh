# This Week Chart from Workouts + Calendar Video Placeholder

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal (user report):** 1) "This Week" chart on the member home screen doesn't update after working out — it must reflect a workout instantly when the member works out. 2) On the calendar, Aug 3's workout video should appear as a view-only placeholder.

**Root causes found (DB-verified):**
1. `homeDataProvider` counted QR check-in rows (`attendance`), not `workout_logs`. M002 has no attendance for Aug 3 → Mon bar = 0 despite the Pull ups workout (proof exists).
2. Home lives in `StatefulShellRoute.indexedStack`, so `initState`-only invalidation never re-fires on tab return → stale chart even after fixing the source.
3. Calendar day detail only showed a "DONE" chip (no way to view the video); the grid cell had no video indicator.

**Decisions:** Only the **This Week** chart switches to workout_logs (user's choice) — Year chart and Month summary stay attendance-based. The calendar video is **viewing only** (no record/delete), reusing the shared centered popup viewer.

**Branch:** `feature/workout-page-v2`.

**Verification baseline:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos OK); `flutter build web --release` → succeeds.

---

## Task 1: This Week chart from workout_logs + instant refresh

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/home/pages/home_page.dart`

- [x] **Step 1:** `homeDataProvider` adds a parallel `workout_logs` query for `logged_at` within this week's UTC bounds (`weekStart` = local Monday midnight → `toUtc()`, `weekEnd` = +7d).
- [x] **Step 2:** `weekCounts` computed from those rows by **PH/local weekday** (`DateTime.parse(logged_at).toLocal()`, Mon-first index `t.weekday - 1`) — Aug 3 01:17 PH → Monday bar = 1.
- [x] **Step 3:** Attendance loop keeps `monthlyCounts`, `monthCounts`, and `openSession` (Year/Month stay attendance); removed the old UTC-vs-local week counting.
- [x] **Step 4:** `_HomePageState` adds a `GoRouter` routerDelegate listener (`didChangeDependencies` + `dispose`): when the location returns to `/member/home`, `ref.invalidate(homeDataProvider)` (cached data stays visible until refresh lands).

## Task 2: Shared popup viewer + calendar video placeholder

**Files:**
- New: `mobile/fitness_app/lib/features/shared/widgets/proof_video_viewer.dart`
- Modify: `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
- Modify: `mobile/fitness_app/lib/features/member/calendar/widgets/month_day_grid.dart`

- [x] **Step 1:** Extracted `showProofVideoDialog(context, videoUrl)` (centered, scale/fade pop, play-first, 15s tap-to-play fallback, X/barrier close, no record/delete) into `proof_video_viewer.dart`.
- [x] **Step 2:** `exercise_proof_button.dart` strip tap → shared `showProofVideoDialog`; private `_ProofViewerDialog` deleted.
- [x] **Step 3:** Calendar back-face row: when `proof_url` exists, show a "▶ Video" chip before the DONE chip → opens the centered viewer (viewing only).
- [x] **Step 4:** Calendar grid cell: tiny `play_circle` icon next to the gym icon when any workout that day has a proof video (Aug 3 visibly "has a video").

## Task 3: Verify + commit

- [x] **Step 1:** `flutter analyze --no-pub` → 0 new issues (13 pre-existing infos).
- [x] **Step 2:** `flutter build web --release` → succeeds.
- [ ] **Step 3 (manual, web — M002):** workout → switch to Home tab → This Week Mon bar = 1 (refetches on return); calendar Aug 3 → play icon on grid cell + "Video" chip in day detail → tap → centered popup plays.
- [ ] **Step 4:** Commit `feat(member): This Week chart from workouts + calendar video placeholder`.
