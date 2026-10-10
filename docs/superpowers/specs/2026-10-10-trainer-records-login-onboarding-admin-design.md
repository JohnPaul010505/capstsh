# Trainer Records Redesign + Login/Onboarding Polish + Admin Enhancements — Design

Date: 2026-10-10
Status: Approved for planning

## Context

Two codebases are in scope:

- **Flutter mobile** — `mobile/fitness_app` (trainer records, login, onboarding).
- **React admin** — `admin` (member/trainer detail, overview charts, membership, reports, predictions).

The trainer record screen is currently a bottom sheet that mixes workouts and foods in one
scroll. Completion "crossing" is wrong in two ways (see below). Login labels float and say
"Member Code". Onboarding is a single long screen that does not reliably trigger for
manually-created members and does not match the add-food wizard look. The admin pages have
read-only fields, mislabelled charts, and a hard-coded `999` inactive sentinel.

## Root-cause findings

1. **Member overlay uses a non-existent column.** `trainer_plan_overlay.dart` auto-check
   queries `workout_logs.created_at`, but `workout_logs` has no `created_at` (only
   `logged_at`, per `00001_initial_schema.sql` + migrations). The query throws, is swallowed,
   and the member's own Day 1 never crosses. The trainer record screen queries `logged_at`
   and therefore crosses. **Fix:** member overlay -> `logged_at`.
2. **Crossing is window-wide, not per-day.** `record_screen.dart::_fetchCompletedNames`
   collects every logged name across the whole 7-day plan window into one `Set`, then marks
   any day's item whose name matches. Two different days that both list "Bench Press" both
   cross. **Fix:** match by calendar day — Day N is `start_date + (N-1)`; cross an item only
   if it was logged on that specific day.

## Goals / success criteria

- Tapping a member opens a **dedicated screen** with two tabs (Workout, Foods), a back "<"
  button, and the same glass style as the rest of the app.
- A plan item crosses **only on the day it was logged**, and the member overlay and trainer
  record agree.
- Login shows **"User code"** with the label pinned **above** the field, Password likewise.
- Manually-created members reliably reach onboarding; onboarding is a gated 4-step wizard
  styled like the add-food wizard.
- Admin member personal info, trainer email/phone/specialty are editable and persist.
- Admin overview shows a **workout** chart for This Week and a **check-in** chart for This
  Month, both driven by the selected date range.
- Admin workout log shows exercise name + a workout total, driven by date.
- Admin food intake shows Kcal / Protein / Carbs / Fat columns.
- Membership "Add member" uses a searchable combobox.
- Inactive report shows realistic (randomised) day counts instead of a blanket `999`.
- Predictions surface the basis for each generated forecast.

## Design

### A. Trainer record — dedicated screen (`record_screen.dart`)

Replace the `showModalBottomSheet` details with a pushed route `/trainer/records/:memberId`
rendering a new `RecordDetailScreen` (new file `record_detail_screen.dart`):

- Header: back "<" (CupertinoButton -> `context.pop()`), member name, days badge.
- A two-tab segmented control (Workout / Foods) in a glass pill; each tab renders its own
  day sections via the existing `_PlanDaySection`-style widget.
- Whole screen uses `AppGlowBackground` + `GlassPanel`; keeps the schedule + notes banner.

Per-day completion: change `_fetchCompletedNames` to return a
`Map<String /*YYYY-MM-DD*/, Set<String>>` for workouts and foods keyed by the logged day
(bucketed locally from `logged_at` / `meal_time`). The screen computes each plan day''s
calendar date as `start_date + (day-1)` and looks up only that day''s set.

### B. Member overlay crossing (`trainer_plan_overlay.dart`)

`_autoCheckFromLogs` (workout) and the food equivalent: query `logged_at` / `meal_time`
instead of the non-existent `created_at`. Keep the same containment matching.

### C. Login (`login_page.dart`)

- `_FloatingLabelInput` -> static top label (no float): render the label above the field at

### E. Admin member detail (`MemberDetailPage.tsx`)

- Personal Information card -> editable: local form state seeded from `member`, Edit/Save
  buttons, persist via `useUpdateMember`.
- Overview: **This Week** card stays a **workout** bar chart; **This Month** card switches to
  a **check-in** bar chart - add an `attendance` fetch keyed to the member + `overviewRange`,
  bucketed daily for the current month.
- Workout Log: add an **Exercise** column (already `workoutName`) and a **Total** column
  (`total_calories` when present, else a duration / sets x reps x weight summary), driven by
  the workouts range.
- Food Intake: replace the combined "Nutrition" cell with four columns: **Kcal**, **Protein**,
  **Carbs**, **Fat**.

### F. Admin trainer detail (`TrainerDetailPage.tsx`)

- Email + Phone cards -> editable (local form + a `useUpdateTrainer` mutation on `profiles`).
- Add a fourth card **Specialty** bound to `profiles.specialty`, editable; keep the header
  line read-only.

### G. Membership (`MembershipsPage.tsx`)

Replace the `MemberSelect` glass dropdown in the "Add membership" drawer with a searchable
combobox (type-to-filter over name/code/email, same visual treatment as the assign-member
drawer's search input), keeping selection by id.

### H. Inactive report (`InactiveReportPage.tsx`)

Replace the `999` sentinel for "never checked in" with a deterministic pseudo-random day
count (seeded from `userId` so it is stable across renders but varied per member), e.g.
`30 + hash(userId) % 240`. Never rows still sort to the top.

### I. Predictions (`PredictionsPage.tsx`)

After generate, the results view already renders `basisText(...)` per forecast. Verify the
post-generate view (not only the Recent table) shows the basis line for each metric; if the
generated view omits it, mirror the `basisText` subtitle used in the table into the generated
cards. No AI-service change.

## Out of scope

- No DB migrations (all columns exist).
- No change to prediction math or AI service.
- No navigation-shell changes beyond the new trainer record route.

## Verification

- Mobile: `cd mobile/fitness_app && flutter analyze --no-pub` -> no issues.
- Admin: `cd admin && npx tsc --noEmit` -> no type errors; `npm run build` succeeds.
- Manual spot-checks per the reference screenshots.

  a fixed small size, or pin it inside at the top with padding. Keep the glass fill/border.
- Label text: code field -> **"User code"**; password field -> **"Password"** (already).

### D. Onboarding (`onboarding_splash_screen.dart`)

Redesign as a 4-step wizard reusing the add-food wizard glass tokens
(`_glassFill`, `_glassBorder`, `_glassDecoration`), a step header with step names
(Profile / Stats / Gender / Avatar):

1. **Welcome** - logo (assets/logo.png, no bg), greeting **"Triple j"**, the supplied
   description, **Start** -> step 2.
2. **Stats** - height + weight glass inputs; **Next disabled until both valid**.
3. **Gender** - two gender cards sized to not crop; **Next disabled until selected**.
4. **Avatar** - profile picker grid; **Save disabled until selected**; on save call
   `completeOnboarding` then `invalidate(needsOnboardingProvider)`.

Reliability fix for manual creation: onboarding triggers off `needsOnboardingProvider`
(member with empty `gender` OR no `body_measurements`). Manual enrollments already set
`gender` from the form (`useEnrollments.ts`) - so a manually-created member with a gender
set will NOT be prompted. To guarantee the wizard still runs for manual creates, gate the
redirect on **no `body_measurements` row** as well (the provider already checks this). No
backend change; keep `completeOnboarding` as the single writer of gender + first measurement.
