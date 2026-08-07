# Workout Persistence + Calendar Instant Update + Landscape Video Viewer

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist completed workout sessions to Supabase so the calendar updates instantly, redesign the video viewer to landscape orientation (staying on-screen as an overlay with X close), and add video proof strips to the Workout Complete summary card.

**Architecture:** Three independent subsystems — (1) workout log persistence on session finish via `WorkoutService.createWorkout()` + provider invalidation for calendar/home refresh, (2) video viewer redesign from centered 640px card to landscape full-width overlay with same-screen playback, (3) inline video strips in the `_buildSummary` exercise list. All changes are Flutter-only (no schema changes — `workout_logs` already has `proof_url`, `proof_type`, `weight_kg` columns from migration 00013).

**Tech Stack:** Flutter, Riverpod, Supabase Dart client, video_player, ClayTokens, PressableCard.

**Branch:** `feature/workout-page-v2` (current).

**Verification baseline:** `flutter analyze --no-pub` → 0 new issues; `flutter build web --release` → succeeds.

---

## Task 1: Fix WorkoutLog model — `weight` → `weight_kg` field alignment

The `WorkoutLog` model serializes `weight` but the DB column added in migration 00013 is `weight_kg`. The calendar provider already selects `weight_kg`. Align the model.

**Files:**
- Modify: `mobile/shared/lib/models/workout_log.dart`

- [ ] **Step 1:** In `workout_log.dart`, rename the `weight` field to `weightKg` throughout:
  - Field: `final double? weightKg;`
  - Constructor param: `this.weightKg,`
  - `fromJson`: `weightKg: (json['weight_kg'] as num?)?.toDouble(),`
  - `toJson`: `'weight_kg': weightKg,`

- [ ] **Step 2:** Search all callers of `WorkoutLog` to update references. Current callers: only `workout_service.dart` (imports the model but `createWorkout` is never called yet). No other files reference `WorkoutLog.weight`.

- [ ] **Step 3:** `flutter analyze --no-pub` → 0 new issues.

- [ ] **Step 4:** Commit `fix(mobile): align WorkoutLog weight field with DB weight_kg column`.

---

## Task 2: Persist workout logs on session finish

When `_finishSession()` fires (all exercises done), iterate over `state.exercises` and insert each into `workout_logs`. This makes exercises appear on the calendar immediately.

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

**Data mapping** (from `SessionExercise` → `workout_logs` row):
| Column | Source |
|---|---|
| `member_id` | `SupabaseClientService().client.auth.currentUser!.id` |
| `exercise_name` | `e.name` |
| `sets` | `null` (session doesn't track sets — only duration) |
| `reps` | `null` |
| `weight_kg` | `_weightKg` (member's body weight from `body_measurements`, used for MET calorie calc) |
| `duration_minutes` | `e.doneAt.difference(e.startedAt).inMinutes` |
| `proof_url` | `e.proofUrl` |
| `proof_type` | `'video'` if `e.hasProof` else `null` |
| `logged_at` | `e.doneAt?.toIso8601String() ?? DateTime.now().toIso8601String()` |

- [ ] **Step 1:** In `workout_session_provider.dart`, add import for `WorkoutService`:
  ```dart
  import 'package:shared/services/workout_service.dart';
  import 'package:shared/models/workout_log.dart';
  ```

- [ ] **Step 2:** Add a new public method `persistSession()` to `WorkoutSessionNotifier`:
  ```dart
  Future<void> persistSession() async {
    final client = SupabaseClientService().client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || state.exercises.isEmpty) return;

    final service = WorkoutService();
    for (final e in state.exercises) {
      if (e.doneAt == null) continue;
      final log = WorkoutLog(
        id: '', // Supabase generates UUID
        memberId: userId,
        exerciseName: e.name,
        durationMinutes: e.doneAt!.difference(e.startedAt ?? state.startedAt ?? e.doneAt!).inMinutes,
        weightKg: _weightKg,
        proofUrl: e.proofUrl,
        proofType: e.hasProof ? 'video' : null,
        loggedAt: e.doneAt!,
      );
      await service.createWorkout(log);
    }
  }
  ```

- [ ] **Step 3:** In `workout_page.dart`, add imports:
  ```dart
  import 'package:flutter_riverpod/flutter_riverpod.dart';
  import '../../../member/calendar/providers/month_entries_provider.dart';
  import '../../../home/pages/home_page.dart';
  ```

- [ ] **Step 4:** In `workout_page.dart`, create a helper method to persist + invalidate:
  ```dart
  Future<void> _persistAndInvalidate() async {
    final notifier = ref.read(workoutSessionProvider.notifier);
    await notifier.persistSession();
    // Invalidate calendar provider for the current month so it re-fetches
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    ref.invalidate(monthEntriesProvider(monthStart));
    // Invalidate home data so This Week chart refreshes
    ref.invalidate(homeDataProvider);
  }
  ```

- [ ] **Step 5:** In the "New Session" button's `onPressed` (workout_page.dart ~line 529), call `_persistAndInvalidate()` before `notifier.restartSession()`:
  ```dart
  onPressed: () async {
    await _persistAndInvalidate();
    notifier.restartSession();
    setState(() => _query = '');
  },
  ```

- [ ] **Step 6:** `flutter analyze --no-pub` → 0 new issues.

- [ ] **Step 7:** Commit `feat(mobile): persist workout logs to Supabase on session finish`.

---

## Task 3: Landscape video viewer overlay (stays on-screen, X to close)

Redesign `proof_video_viewer.dart` so the dialog is landscape-oriented (wide rectangle, not square-ish centered card). The video stays on the same screen — no route navigation. X button closes.

**Files:**
- Modify: `mobile/fitness_app/lib/features/shared/widgets/proof_video_viewer.dart`

- [ ] **Step 1:** Replace the `Center` → `ConstrainedBox(maxWidth: 640)` → `AspectRatio(16/9)` layout with a landscape-oriented overlay that fills more of the screen width:

  ```dart
  // In _ProofViewerDialogState.build():
  return Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.92,
        maxHeight: MediaQuery.of(context).size.height * 0.55,
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2A2A45)),
          ),
          child: Stack(/* ... existing children ... */),
        ),
      ),
    ),
  );
  ```

  This makes the video take up ~92% of screen width and ~55% of screen height — a wide landscape rectangle that stays on the workout/calendar screen.

- [ ] **Step 2:** Keep the existing X button (top-right close), play/pause toggle, 15s timeout fallback, and error state — all unchanged.

- [ ] **Step 3:** Keep the existing `barrierColor: Colors.black.withAlpha(210)` — dark semi-transparent backdrop that keeps the underlying screen visible.

- [ ] **Step 4:** `flutter analyze --no-pub` → 0 new issues.

- [ ] **Step 5:** Commit `feat(mobile): landscape video viewer overlay stays on screen`.

---

## Task 4: Add video proof strips to Workout Complete summary card

In `_buildSummary()`, each exercise row currently shows a green/red circle, name · duration, and calories. Add a conditional video strip below each exercise: if proof exists → tappable "Video saved · tap to view" strip; if no proof → muted "No video" placeholder.

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [ ] **Step 1:** Add import for the video viewer:
  ```dart
  import '../../../shared/widgets/proof_video_viewer.dart';
  ```

- [ ] **Step 2:** In `_buildSummary()`, modify the `.map()` over `session.exercises` (lines ~481-513). Each exercise currently returns a single `Padding` widget with a `Row`. Change it to return a `Column` containing:
  1. The existing row (green/red circle, name · duration, kcal)
  2. A new video strip widget (conditional on `hasVideo`)

  The video strip widget:
  - **If `e.hasProof` is true:**
    ```dart
    GestureDetector(
      onTap: () => showProofVideoDialog(context, e.proofUrl!),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2A2A45)),
        ),
        child: Row(
          children: [
            const Icon(Icons.play_circle_outline, size: 16, color: Colors.white54),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Video saved · tap to view', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB4B4D0),
              )),
            ),
            Container(
              width: 5, height: 5,
              decoration: const BoxDecoration(
                color: Color(0xFF6EE7B7),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
    ```
  - **If `e.hasProof` is false:**
    ```dart
    Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: ClayTokens.clayDarkSurfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF2A2A45)),
      ),
      child: const Row(
        children: [
          Icon(Icons.videocam_outlined, size: 14, color: Color(0xFF636366)),
          SizedBox(width: 8),
          Text('No video', style: TextStyle(fontSize: 10, color: Color(0xFF636366))),
        ],
      ),
    );
    ```

- [ ] **Step 3:** Wrap the entire exercise item (existing row + new video strip) in a `Column` with `mainAxisSize: MainAxisSize.min`, and add `const SizedBox(height: 6)` between the two.

- [ ] **Step 4:** `flutter analyze --no-pub` → 0 new issues.

- [ ] **Step 5:** Commit `feat(mobile): add video proof strips to Workout Complete card`.

---

## Task 5: Calendar back-face video viewer uses landscape overlay

The calendar's `_BackFace` already calls `showProofVideoDialog()` when tapping the "Video" chip. Since Task 3 updates the shared `proof_video_viewer.dart`, the calendar automatically gets the landscape viewer. Verify no changes needed.

**Files:**
- Verify: `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart` (line 333)

- [ ] **Step 1:** Confirm `calendar_flip_sheet.dart` line 333 calls `showProofVideoDialog(context, url)` — this will use the updated landscape viewer from Task 3 with zero changes.

- [ ] **Step 2:** `flutter analyze --no-pub` → 0 new issues.

- [ ] **Step 3:** No commit needed (verified, no code change).

---

## Task 6: Fix `flutter_lints` include in analysis_options.yaml

The `analysis_options.yaml` includes `package:flutter_lints/flutter.yaml` but that package is not in `pubspec.yaml`. This causes an `include_file_not_found` error.

**Files:**
- Modify: `mobile/fitness_app/pubspec.yaml`
- Verify: `mobile/fitness_app/analysis_options.yaml`

- [ ] **Step 1:** Add `flutter_lints` to `dev_dependencies` in `pubspec.yaml`:
  ``yaml
  dev_dependencies:
    flutter_test:
      sdk: flutter
    flutter_lints: ^5.0.0
  ``

- [ ] **Step 2:** Run `flutter pub get` in `mobile/fitness_app/` to install the package.

- [ ] **Step 3:** Verify `analysis_options.yaml` line 10 still reads `include: package:flutter_lints/flutter.yaml` — no change needed.

- [ ] **Step 4:** `flutter analyze --no-pub` → 0 new issues (the `include_file_not_found` error is resolved).

- [ ] **Step 5:** Commit `fix(mobile): add flutter_lints dependency to resolve analysis_options include error`.

---

## Task 7: Fix `withOpacity` deprecation in login_page.dart

Flutter's `Color.withOpacity()` is deprecated in favor of `Color.withValues(alpha:)` to avoid precision loss. There are 12 occurrences in `login_page.dart`.

**Files:**
- Modify: `mobile/fitness_app/lib/features/auth/pages/login_page.dart`

**All 12 replacements** (same pattern — `.withOpacity(x)` → `.withValues(alpha: x)`):

| Line | Before | After |
|---|---|---|
| 151 | `CupertinoAppColors.purple.withOpacity(0.26)` | `CupertinoAppColors.purple.withValues(alpha: 0.26)` |
| 152 | `CupertinoAppColors.purple.withOpacity(0.0)` | `CupertinoAppColors.purple.withValues(alpha: 0.0)` |
| 164 | `CupertinoAppColors.primaryBlue.withOpacity(0.22)` | `CupertinoAppColors.primaryBlue.withValues(alpha: 0.22)` |
| 165 | `CupertinoAppColors.primaryBlue.withOpacity(0.0)` | `CupertinoAppColors.primaryBlue.withValues(alpha: 0.0)` |
| 199 | `CupertinoAppColors.separator.withOpacity(0.5)` | `CupertinoAppColors.separator.withValues(alpha: 0.5)` |
| 204 | `CupertinoAppColors.purple.withOpacity(0.12)` | `CupertinoAppColors.purple.withValues(alpha: 0.12)` |
| 318 | `CupertinoAppColors.red.withOpacity(0.12)` | `CupertinoAppColors.red.withValues(alpha: 0.12)` |
| 322 | `CupertinoAppColors.red.withOpacity(0.3)` | `CupertinoAppColors.red.withValues(alpha: 0.3)` |
| 375 | `CupertinoAppColors.primaryBlue.withOpacity(0.35)` | `CupertinoAppColors.primaryBlue.withValues(alpha: 0.35)` |
| 434 | `CupertinoAppColors.primaryBlue.withOpacity(0.38)` | `CupertinoAppColors.primaryBlue.withValues(alpha: 0.38)` |
| 535 | `CupertinoAppColors.primaryBlue.withOpacity(0.6)` | `CupertinoAppColors.primaryBlue.withValues(alpha: 0.6)` |
| 536 | `CupertinoAppColors.separator.withOpacity(0.4)` | `CupertinoAppColors.separator.withValues(alpha: 0.4)` |

- [ ] **Step 1:** Open `login_page.dart` and replace all 12 `.withOpacity(` calls with `.withValues(alpha: `. Use `replaceAll` if the editor supports it, or replace line by line.

- [ ] **Step 2:** `flutter analyze --no-pub` → 0 new issues (all `deprecated_member_use` warnings resolved).

- [ ] **Step 3:** Commit `fix(mobile): replace deprecated withOpacity with withValues in login_page.dart`.

---

## Task 8: End-to-end verification

- [ ] **Step 1:** `flutter analyze --no-pub` from `mobile/fitness_app/` → 0 new issues.
- [ ] **Step 2:** `flutter build web --release` → succeeds.
- [ ] **Step 3 (manual, web — M002):** Login M002 / `123456789`. Workout tab → add exercise → Start Session → record proof → Done → summary card shows with video strip ("Video saved · tap to view"). Tap strip → landscape video overlay opens on same screen → X closes.
- [ ] **Step 4 (manual):** Tap "New Session" → exercises persist to Supabase. Open calendar → current month shows dumbbell icon on today → tap day → back face shows exercise with "Video" chip.
- [ ] **Step 5 (manual):** Calendar "Video" chip → landscape video overlay opens on same screen → X closes. No screen navigation.
- [ ] **Step 6 (manual):** Exercise without proof → summary card shows "No video" placeholder strip → calendar shows "MISSING VIDEO" chip for today.

