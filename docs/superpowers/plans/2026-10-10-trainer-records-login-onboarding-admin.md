# Trainer Records / Login / Onboarding / Admin — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the trainer record screen into a two-tab dedicated screen with per-day completion crossing; polish login labels; rebuild onboarding as a gated 4-step wizard; and make the requested React admin enhancements.

**Architecture:** Flutter side gets a new `record_detail_screen.dart` route plus a per-day bucketed completion fetcher and a `created_at`->`logged_at` fix in the member overlay. React side edits existing pages in place.

**Tech Stack:** Flutter/Riverpod/go_router (mobile); React + TypeScript + TanStack Query + Tailwind (admin).

**Spec:** docs/superpowers/specs/2026-10-10-trainer-records-login-onboarding-admin-design.md

## Global Constraints

- No DB migrations — every column referenced already exists (`workout_logs.logged_at`, `meal_logs.meal_time`, `profiles.specialty`, `attendance.check_in_date`, `workout_logs.total_calories`).
- Mobile check: `cd mobile/fitness_app && flutter analyze --no-pub` must report **No issues found** before finishing.
- Admin check: `cd admin && npx tsc --noEmit` must pass before finishing.
- Preserve the glass visual system: reuse `GlassPanel` / `GlassSheetShell` / `AppGlowBackground` (mobile), the add-food wizard tokens `_glassFill/_glassFillStrong/_glassBorder/_glassDecoration` (mobile), and `glass-card` classes (admin).
- Do not change navigation shells beyond adding the trainer record route.
- Commit after each task with a focused message.

## File Structure

Mobile (`mobile/fitness_app/lib/features/`):
- `trainer/set_plan/pages/record_detail_screen.dart` — NEW: two-tab detail screen + per-day completion.
- `trainer/set_plan/pages/record_screen.dart` — MODIFY: tap pushes the new route.
- `shared/widgets/trainer_plan_overlay.dart` — MODIFY: `created_at`->`logged_at`.
- `auth/pages/login_page.dart` — MODIFY: static top labels, "User code".
- `member/onboarding/pages/onboarding_splash_screen.dart` — MODIFY: 4-step wizard.
- `app/router.dart` — MODIFY: add `/trainer/records/:memberId` route.

Admin (`admin/src/features/`):
- `members/pages/MemberDetailPage.tsx` — editable info; overview This Month -> check-ins; workout Total column; food Kcal/Protein/Carbs/Fat columns.
- `trainers/pages/TrainerDetailPage.tsx` + `trainers/hooks/useTrainers.ts` — editable email/phone + new Specialty card.
- `memberships/pages/MembershipsPage.tsx` — searchable member combobox.
- `reports/pages/InactiveReportPage.tsx` — random inactive days.


---

## Task 1 — Fix member overlay crossing (`created_at` -> `logged_at`)

**Files:** `mobile/fitness_app/lib/features/shared/widgets/trainer_plan_overlay.dart`

- [ ] **Step 1:** In `_TrainerPlanWorkoutOverlayState._autoCheckFromLogs`, the workout query
filters `.gte('created_at', ...)` / `.lt('created_at', ...)`. Replace both occurrences of the
column name `created_at` with `logged_at`.

- [ ] **Step 2:** Verify no other `created_at` reference remains.
Run: `Select-String -Path mobile/fitness_app/lib/features/shared/widgets/trainer_plan_overlay.dart -Pattern created_at`
Expected: no matches.

- [ ] **Step 3:** `cd mobile/fitness_app && flutter analyze --no-pub` -> No issues found.

- [ ] **Step 4:** Commit
```bash
git add mobile/fitness_app/lib/features/shared/widgets/trainer_plan_overlay.dart
git commit -m "fix(member): overlay auto-check reads logged_at not missing created_at"
```

---

## Task 2 — Per-day completion fetcher + record detail screen

**Files:** NEW `record_detail_screen.dart`; MODIFY `record_screen.dart`; MODIFY `app/router.dart`.

- [ ] **Step 1:** Create `record_detail_screen.dart` exposing
`RecordDetailScreen({required String memberId, required String memberName})`.
Inside, a `FutureBuilder` loads the plan via `PlanRepository().getPlanByMember(memberId)` and
calls a new top-level
`Future<(Map<String,Set<String>>, Map<String,Set<String>>)> fetchCompletedByDay(memberId, startDate, endDate)`
that queries `workout_logs.exercise_name,logged_at` and `meal_logs.food_name,meal_time`
in the window and buckets each row into a `YYYY-MM-DD` key (local day via
`DateTime.parse(x).toLocal()` -> `toIso8601String().split('T').first`).

- [ ] **Step 2:** Compute each plan day's date: `startDate + Duration(days: day-1)`. Build
`({String text, bool done})` items by looking up only that day's set (reuse
`_normPlanName` + the containment match `_planNameLogged` copied here).

- [ ] **Step 3:** UI: `Scaffold` + `AppGlowBackground`; header row with CupertinoButton back
(`context.pop()`), centered member name, days badge; a two-tab glass pill segmented control
(`_RecordTab.workout | _RecordTab.food`); body renders `_PlanDaySection` list for the active
tab inside a `SingleChildScrollView`; schedule + notes banner preserved.

- [ ] **Step 4:** `record_screen.dart`: change `onTap` to push
`/trainer/records/${memberId}?name=${Uri.encodeComponent(memberName)}`. Delete the unused
`_showPlanDetails`, `_fetchCompletedNames`, `_exerciseItem`, and `_PlanDaySection` from
`record_screen.dart` (they move to the detail file). Keep the list + header + provider.

- [ ] **Step 5:** `app/router.dart`: add the GoRoute before the member shell:
```dart
GoRoute(
  path: '/trainer/records/:memberId',
  pageBuilder: (_, state) => _iosPush(RecordDetailScreen(
    memberId: state.pathParameters['memberId']!,
    memberName: state.uri.queryParameters['name'] ?? 'Member',
  )),
),
```
Import the new file.

- [ ] **Step 6:** `flutter analyze --no-pub` -> No issues found.

- [ ] **Step 7:** Commit
```bash
git add mobile/fitness_app/lib/features/trainer/set_plan/pages/record_detail_screen.dart \
        mobile/fitness_app/lib/features/trainer/set_plan/pages/record_screen.dart \
        mobile/fitness_app/lib/app/router.dart
git commit -m "feat(trainer): two-tab record detail screen with per-day completion"
```

---

## Task 3 — Login labels: static top label + "User code"

**Files:** `mobile/fitness_app/lib/features/auth/pages/login_page.dart`

- [ ] **Step 1:** In `_FloatingLabelInputState.build`, pin the label to the top always:
change `top: floating ? 6 : 14` to a fixed `top: 6`, and force `fontSize: 11` (drop the
`floating ? 11 : 15` ternary). Keep glass fill/border/focus ring.

- [ ] **Step 2:** Rename the code field label from `'Member Code'` to `'User code'`.

- [ ] **Step 3:** `flutter analyze --no-pub` -> No issues found.

- [ ] **Step 4:** Commit
```bash
git add mobile/fitness_app/lib/features/auth/pages/login_page.dart
git commit -m "feat(auth): pin login labels to top, rename code field to User code"

---

## Task 4 — Onboarding 4-step wizard

**Files:** `mobile/fitness_app/lib/features/member/onboarding/pages/onboarding_splash_screen.dart`

- [ ] **Step 1:** Add step state `int _step = 0` (0 Welcome, 1 Stats, 2 Gender, 3 Avatar) and a
`_stepNames = const ['Profile','Stats','Gender','Avatar']`. Define the add-food glass tokens
locally and render a top step bar (four labelled segments).

- [ ] **Step 2:** Step 0 (Welcome): logo `Image.asset('assets/logo.png', 96)` no background,
title **"Triple j"**, the description
"Your fitness journey starts here. Track your workouts, monitor your progress, and stay motivated as you work toward your fitness goals. Let's personalize your experience and build a healthier, stronger you one step at a time!",
and a **Start** button (`setState(() => _step = 1)`).

- [ ] **Step 3:** Step 1 (Stats): height + weight glass inputs bound to existing
controllers/validators; **Next** enabled only when `_heightValid && _weightValid`.

- [ ] **Step 4:** Step 2 (Gender): the two `_genderCard`s with `fit: BoxFit.contain` and a
bounded image box (fix the crop); **Next** enabled only when `_gender != null`.

- [ ] **Step 5:** Step 3 (Avatar): existing profile grid; **Save** enabled only when
`_selectedProfile != null`; on save run the existing `_handleSave`.

- [ ] **Step 6:** `flutter analyze --no-pub` -> No issues found.

- [ ] **Step 7:** Commit
```bash
git add mobile/fitness_app/lib/features/member/onboarding/pages/onboarding_splash_screen.dart
git commit -m "feat(onboarding): gated 4-step wizard in add-food glass style"
```

---

## Task 5 — Admin member detail: editable info + overview/charts/columns

**Files:** `admin/src/features/members/pages/MemberDetailPage.tsx`

- [ ] **Step 1:** Import `useUpdateMember`. Add `editing` + `form` state seeded from `member`.
Personal Information card: read-only values, or when `editing`, inputs for
phone/date_of_birth/gender/address/emergency fields; **Save** calls
`useUpdateMember().mutate({ id, ...form })`; **Edit** toggles.

- [ ] **Step 2:** Overview This Month -> check-ins: add a query for `attendance.check_in_date`
(select, eq member_id, gte/lte unless allTime, limit 2000). Extend the `overview` memo to
build `checkins.month` (daily buckets this month) from a second counts map keyed by
`check_in_date`. Point the "This Month" `<BarTrend>` at the check-in series; keep "This Week"
on the workout series.

- [ ] **Step 3:** Workout Log: add a **Total** column after Duration — `total_calories` kcal
when present, else a sets x reps x weight volume summary.

- [ ] **Step 4:** Food Intake: replace the single `nutrition` column with four columns
**Kcal / Protein / Carbs / Fat** rendering `m.calories`, `m.protein_g`, `m.carbs_g`,
`m.fat_g` with `?? '—'`.

- [ ] **Step 5:** `cd admin && npx tsc --noEmit` -> no errors.

- [ ] **Step 6:** Commit
```bash
git add admin/src/features/members/pages/MemberDetailPage.tsx
git commit -m "feat(admin): editable member info, check-in month chart, workout total, food macro columns"
```

---

## Task 6 — Admin trainer detail: editable email/phone + Specialty card

**Files:** `admin/src/features/trainers/hooks/useTrainers.ts`; `admin/src/features/trainers/pages/TrainerDetailPage.tsx`

- [ ] **Step 1:** Add `useUpdateTrainer` to `useTrainers.ts` (update `profiles` by id,
invalidate `['trainer', id]`), mirroring `useUpdateMember`.

- [ ] **Step 2:** Add `editing` + `form` state seeded from `trainer`; wire Email and Phone
cards to editable inputs; add a fourth **Specialty** card bound to `profiles.specialty`; a
single **Save** persists email/phone/specialty via the new mutation.

- [ ] **Step 3:** `cd admin && npx tsc --noEmit` -> no errors.

- [ ] **Step 4:** Commit
```bash
git add admin/src/features/trainers/hooks/useTrainers.ts admin/src/features/trainers/pages/TrainerDetailPage.tsx
git commit -m "feat(admin): editable trainer email/phone + Specialty card"
```


---

## Task 7 — Admin membership: searchable member combobox

**Files:** `admin/src/features/memberships/pages/MembershipsPage.tsx`

- [ ] **Step 1:** Add a search input inside the `MemberSelect` dropdown panel filtering the
`members` list by name/code/email (same styling as the assign drawer's search box); keep
selection-by-id and outside-click close.

- [ ] **Step 2:** `cd admin && npx tsc --noEmit` -> no errors.

- [ ] **Step 3:** Commit
```bash
git add admin/src/features/memberships/pages/MembershipsPage.tsx
git commit -m "feat(admin): searchable member combobox in add-membership drawer"
```

---

## Task 8 — Admin inactive report: random inactive days

**Files:** `admin/src/features/reports/pages/InactiveReportPage.tsx`

- [ ] **Step 1:** Replace the `999` sentinel with a stable pseudo-random value:
```ts
const hash = (s: string) => { let h = 0; for (const c of s) h = (h * 31 + c.charCodeAt(0)) | 0; return Math.abs(h) }
// where daysInactive was 999:
daysInactive: 30 + (hash(m.member_id) % 240)
```
Apply to both members and trainers queries. Keep `lastCheckIn: null` for never rows.

- [ ] **Step 2:** `cd admin && npx tsc --noEmit` -> no errors.

- [ ] **Step 3:** Commit
```bash
git add admin/src/features/reports/pages/InactiveReportPage.tsx
git commit -m "feat(admin): randomised inactive-day counts instead of 999 sentinel"
```

---

## Task 9 — Verify predictions basis + final analyze

**Files:** `admin/src/features/predictions/pages/PredictionsPage.tsx` (verify only)

- [ ] **Step 1:** Confirm the post-generate results view renders `basisText(...)` per forecast.
If the generated card grid omits it, add the `basisText` subtitle under each card's value.

- [ ] **Step 2:** Mobile: `cd mobile/fitness_app && flutter analyze --no-pub` -> No issues found.

- [ ] **Step 3:** Admin: `cd admin && npx tsc --noEmit` -> no errors.

- [ ] **Step 4:** Commit any change.

---

## Review Focus

- Per-day bucketing timezone: bucket with `DateTime.parse(x).toLocal()` so a PH member's day
  boundaries match; verify a Day-1-only log does not cross Day-3 items sharing a name.
- Record detail reads the plan by memberId — confirm it shows the same foods/exercises the
  trainer built (grouped per-day `foods`/`exercises` nested shape).
- Onboarding gating: a manual member WITH gender set but NO `body_measurements` must still
  enter the wizard, and saving must clear the redirect.
- Admin check-in chart: bucket by the `check_in_date` string directly (no TZ conversion).
- Editable trainer/member persists only the changed fields and invalidates the right query key.

```
