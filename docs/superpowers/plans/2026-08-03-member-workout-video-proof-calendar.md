# Member Workout Video Proof + Calendar Flip-Card + M002 Mock Data Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Auto video-proof capture (3s countdown → 30s auto-record → view/remove/re-record) gating session completion, clay-aligned Add Exercise form, flip-card calendar with switch toggle + barbell day icons, and M002-only mock data so the member home charts are verifiable.

**Architecture:** `camera` package replaces `image_picker` for full recording control (web falls back to image_picker). Video tile lives in the exercise card; "Check Videos" gates "Done Workout Session". Calendar becomes a front/back flip card (rotateY) toggled by a clay switch; back face shows the selected day's workout card. Seed script = dev-only, service-role, deterministic, idempotent, targets only `code='M002'` (John Paul Hoquiton — the owner's own account; password `123456789` must never be touched).

**Tech Stack:** Flutter, camera, video_player, image_picker (web fallback), supabase_flutter, flutter_riverpod, go_router, ClayTokens. Node seed script with `@supabase/supabase-js`.

**Branch:** `feature/workout-video-proof-calendar` created from `feature/workout-page-v2` (no overlap with uncommitted WIP: login/meals/trainer-dashboard/member-detail).

**Verification baseline:** `flutter analyze` (0 new issues; 13 pre-existing infos OK) + `flutter build web --release`. Camera flows are device-only (Windows/web dev machine) — the button falls back to image_picker on web so upload/link logic stays testable.

---

## Task 1: M002 mock data seed (FIRST — home screen verifiable immediately)

**Files:**
- Create: `admin/scripts/seed-m002.mjs`
- Modify: `admin/package.json` (add `"seed:m002": "node scripts/seed-m002.mjs"` to scripts)

M002's data before seeding (verified 2026-08-03): attendance = 2 rows (Jul 13, Jul 31, both open), measurements = 0, workouts = 2, membership = Daily (Jul 13–14, active), assignment = 1 active trainer, goals = 0.

- [x] **Step 1:** Script skeleton copied from `seed-dev.mjs` (dotenv, service-role client, `mulberry32(20260803)`, deterministic `uuid()` prefixes `1c01e0b0`/`1c01e0b1`/`1c01e0b2`, PH wall-date helper, `upsertChunks` with `onConflict: 'id', ignoreDuplicates: true`). Look up profile by `code='M002'` → exit if not found. **Never touch auth/password.**
- [x] **Step 2: attendance** (relative to run date):
  - Today: 3 rows — `07:45→09:30` closed, `12:10→13:05` closed, `17:20` open (`check_out_time: null`, `expires_at: +12h`) → This Week bar (height 3) + Daily membership countdown card
  - This month, business days (Mon–Sat) before today: 1 closed row each
  - Past 7 months of the current year: ~55% of business days, 1 closed row each → Jan–Dec area chart
- [x] **Step 3: body_measurements** (8 rows): one per month for current + previous 7 months, fixed trend `94.2, 93.1, 92.0, 90.8, 89.7, 88.5, 87.6, 86.4` kg, `height_cm 172`, `body_fat_pct 26.0, 25.4, 24.8, 24.1, 23.5, 22.8, 22.2, 21.5`, measured ~5th–10th 08:00 (current month = run-day 07:00)
- [x] **Step 4: workout_logs**: today = Bench Press 4×10×60 (08:10), Squat 4×12×80 (08:40), Deadlift 3×8×100 (09:10) — inside the 07:45–09:30 window and ≥08:00 PH so UTC instants land on today (workout page queries naive PH-day strings as UTC); on ~60% of seeded attendance days (this month + past months), 2–4 exercises from the seed-dev `EXERCISES` list, `logged_at` inside the check-in window. `proof_url/proof_type` = null everywhere (tests MISSING VIDEO state)
- [x] **Step 5:** Run `npm run seed:m002` (from `admin/`) → prints counts; re-run → same counts (idempotent)
- [x] **Step 6 (read-only verify):** node query — M002: 104+2 attendance, 8 measurements, 195+2 workouts; Jul 13/Jul 31 stale open rows untouched; today's open row at 17:20 PH with expires_at +12h
- [ ] **Step 7:** Manual: login M002 / `123456789` in the member app → This Week bar (today, height 3), This Month Jan–Aug line + "Total: N" pill, Growth Over Time line + "86.4 kg" pill, Daily countdown membership card, trainer card

## Task 2: `camera` dependency + platform permissions

**Files:**
- Modify: `mobile/fitness_app/pubspec.yaml`
- Modify: `mobile/fitness_app/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/fitness_app/ios/Runner/Info.plist` (SKIPPED — Android-only project, no ios/ directory exists)

- [x] **Step 1:** `flutter pub add camera` in `mobile/fitness_app/` (camera 0.12.0+2)
- [x] **Step 2:** AndroidManifest: add `<uses-permission android:name="android.permission.CAMERA"/>` + `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
- [x] **Step 3:** Info.plist: N/A — Android-only project (verified: no ios/ dir)
- [x] **Step 4:** `flutter analyze` → 0 new issues

## Task 3: `proof_camera_screen.dart` — 3s countdown → 30s auto-record → preview

**Files:**
- Create: `mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart`

- [x] **Step 1:** Full-screen `ProofCameraScreen` route (returns `String?` public URL via `Navigator.pop`):
  - `CameraController` (back camera), live preview, dark overlay
  - **3-2-1 countdown** (large animated numbers, cancel) → auto `startVideoRecording()`
  - **30s progress bar/ring** + live elapsed timer, cancel → auto `stopVideoRecording()` at 30s
  - **Preview** (`VideoPlayerController.file`, looping) with **Keep** / **Retake** (delete temp, restart countdown) / **Cancel** (delete temp, pop null)
  - Keep → `uploadBinary('proofs', 'workouts/{userId}/{epoch}.mp4', video/mp4)` → `getPublicUrl` → pop(url)
  - Permission denied / no camera / init error → error view, pop null
- [x] **Step 2:** Web guard: if `kIsWeb`, error view shown; caller uses the image_picker fallback (Task 4); page never opened on web
- [x] **Step 3:** `flutter analyze` → clean

## Task 4: `exercise_proof_button.dart` rework → video tile (view / remove / re-record)

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

- [x] **Step 1:** New `ExerciseProofTile({String? videoUrl, ValueChanged<String> onRecorded, VoidCallback onRemoved})`:
  - No video → **16:9 dashed placeholder** "No video proof yet" + record button → `Navigator.push(ProofCameraScreen)`; web fallback = existing `pickVideo(camera)` flow with ≥30s check
  - Busy → spinner
  - Video → **film tile** (dark, play icon, "Proof video" label) → tap opens full-screen player page (`video_player`) with **Re-record** and **Remove**; Remove → confirm dialog → `onRemoved()`
- [x] **Step 2:** `workout_page.dart` `_ExerciseCard` becomes two-part: info row (name/sets/reps/chips) + `ExerciseProofTile` below (tile only when `isToday`); `onProofRemoved` wired to `_removeProofFor` (storage delete + `proof_url/proof_type` null + gate reset)
- [x] **Step 3:** `flutter analyze` → clean

## Task 5: Video-check gate in `workout_page.dart`

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [x] **Step 1:** New state `bool _videoCheckPassed = false;`
- [x] **Step 2:** After Finish (`_timerStopped && !_showSummary`): if `!_videoCheckPassed` → **"Check Videos"** button (green, video icon); else → existing green **"Done Workout Session"** button
- [x] **Step 3:** Check Videos tap: scan session exercises — all `proof_url != null` → `_videoCheckPassed = true`; else red **MISSING VIDEO** chips on video-less cards + Cupertino dialog listing missing exercise names ("record proof videos first")
- [x] **Step 4:** `showPending` = `_timerStopped && !_showSummary && !_videoCheckPassed`; chip text → "MISSING VIDEO" (red)
- [x] **Step 5:** New `_removeProofFor(exercise)`: parse storage path from URL (`/object/public/proofs/`), `storage.remove([path])`, `update({proof_url: null, proof_type: null})`, invalidate, and reset `_videoCheckPassed = false`
- [x] **Step 6:** `_addExercise` success → `_videoCheckPassed = false`; `_finishSession` → `_videoCheckPassed = false`
- [x] **Step 7:** `flutter analyze` → clean

## Task 6: Add Exercise form UX/UI restyle

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` (`_buildAddForm`)

- [x] **Step 1:** Clay-aligned restyle: card padding 14, "New Exercise" section label with purple icon, field labels `clayDarkTextTertiary`, muted `helperText`, filled inputs `clayDarkSurfaceElevated` + `clayDarkBorder` (focused `clayPrimaryLight`), submit = **purple gradient pill** (`0xFF5E3AEE → 0xFFC56BF0`, radius 999, matching summary card), Cancel toggle unchanged
- [x] **Step 2:** Note: reference image unseen — systematic clay alignment; refinable later
- [x] **Step 3:** `flutter analyze` → clean

## Task 7: Flip-card calendar + clay switch + barbell icons

**Files:**
- Create: `mobile/fitness_app/lib/features/member/calendar/widgets/flip_card.dart`
- Create: `mobile/fitness_app/lib/features/member/calendar/widgets/clay_switch.dart`
- Create: `mobile/fitness_app/lib/features/member/calendar/widgets/day_workout_card.dart`
- Modify: `mobile/fitness_app/lib/features/member/calendar/pages/calendar_page.dart`

- [x] **Step 1:** `FlipCard({Widget front, Widget back, bool flipped, Duration duration = 600ms})` — `AnimationController` + `AnimatedBuilder`; both faces in a Stack; each wrapped in `Transform(alignment: center, transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(angle))`; back rotated −π; hidden face wrapped in `IgnorePointer` + `Visibility` (maintainState) beyond 90°
- [x] **Step 2:** `ClaySwitch({bool value, ValueChanged<bool> onChanged})` — React-reference toggle adapted to clay: base pill + raised handle knob; off = grey, on = green (`clayAccent`); 42×24, tappable
- [x] **Step 3:** `DayWorkoutCard({DateTime day, List<Map<String, dynamic>> workouts, bool isToday})` — gradient session-summary style (radial purple glow, divider): date header ("EEEE, MMM d, yyyy"), exercise rows (name + sets/reps/weight + DONE chip from `proof_url`, MISSING VIDEO chip when today & no proof), centered **"No Workout in this Day"** when empty
- [x] **Step 4:** `calendar_page.dart` — front face = current calendar **unchanged size/position** (46px cells, same paddings/header); workout days show `Icons.fitness_center` (size 10, `clayAccent`) under the number instead of the green dot (meals keep amber dot); tap day → `_selectedDay` (purple ring) + existing bottom sheet; **clay switch below the grid** ("Calendar | Workout") flips to the back face (`DayWorkoutCard` for `_selectedDay` from `monthEntriesProvider` data); month shift resets selection to day 1
- [x] **Step 5:** `flutter analyze` → clean

## Task 8: End-to-end verification

- [x] **Step 1:** `flutter analyze --no-pub` from `mobile/fitness_app` → 0 new issues (13 pre-existing)
- [x] **Step 2:** `flutter build web --release` → succeeds
- [x] **Step 3:** `npm run seed:m002` re-run → idempotent counts (104 attendance / 8 measurements / 195 workouts)
- [ ] **Step 4:** Manual M002 (`123456789`): home charts ✓; calendar barbells + flip + day card + "No Workout in this Day" ✓; workout page: today's 3 exercises, Finish → Check Videos → MISSING VIDEO on all 3 → record → gate passes → Done → summary → restart ✓
- [ ] **Step 5:** Device-only (real phone): countdown → 30s auto-record → Keep/Retake/Remove; web fallback covers dev machine
