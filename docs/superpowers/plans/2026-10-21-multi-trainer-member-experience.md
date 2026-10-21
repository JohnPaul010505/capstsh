# Multi-trainer Member Experience Implementation Plan

> **For agentic workers:** Execute inline task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Support up to five active trainers per member, with independent chats and plans, member-controlled plan display, and consistent admin/member UI.

**Architecture:** Add a Supabase migration that enforces the active assignment cap, adds a member-safe plan display RPC, and backfills the prior single-plan behavior. Update the admin assignment and detail screens, then make the Flutter member chat, plan, and plan-overlay flows trainer-specific while reusing existing glass/theme components.

**Tech Stack:** Supabase PostgreSQL migrations/RLS/RPC, React + TypeScript + Vite admin, Flutter + Riverpod + GoRouter member app.

**Spec:** `docs/superpowers/specs/2026-10-21-multi-trainer-member-experience-design.md`

## Global Constraints

- A member may have at most five active trainer assignments; inactive history does not count.
- Existing enrollment screening capture and stored responses remain intact; only its section on admin member details is removed.
- Chat rooms remain separate per member/trainer pair and are not created when listing trainers.
- A trainer may update or replace only their own plan for that member; other trainers' plans and completions remain intact.
- Members may change only their own plan's display state; trainer-authored plan fields remain trainer-controlled.
- Workout and Food Intake share the selected displayed plan and completion remains keyed by `plan_id`.
- Follow existing light/dark glass surfaces and readable app tokens.
- Do not add or run tests unless the user asks; use the project build/static checks and direct inspection for verification.

---

### Task 1: Supabase multi-trainer and display migration

**Files:**
- Create: `supabase/migrations/0052_multi_trainer_member_experience.sql`

**Interfaces:**
- Produces `member_goal_plans.is_displayed boolean not null default false`.
- Produces RPC `public.set_member_plan_displayed(p_plan_id uuid, p_is_displayed boolean) returns void`, callable by authenticated members only for their own plan.
- Produces a trigger that rejects inserts/updates that would leave a member with more than five active trainer assignments, serializing changes per member.

- [ ] Add the display column and backfill one most-recent eligible active plan per member to `is_displayed = true`; leave all other rows false.
- [ ] Add `set_member_plan_displayed` as a narrowly scoped security-definer function with a fixed safe `search_path`, member ownership check against `auth.uid()`, and no ability to update any other field.
- [ ] Add/revoke execute grants so authenticated users can call the RPC and anonymous users cannot.
- [ ] Add the active assignment trigger. Acquire a transaction-scoped advisory lock derived from `member_id`, count active rows excluding the row being updated, and reject the sixth active row with stable error text `MEMBER_TRAINER_LIMIT_REACHED`.
- [ ] Ensure transitions to inactive and same-member/same-trainer updates do not falsely fail.
- [ ] Review migration ordering and SQL syntax without editing the existing user change in `0050_enrollment_health_and_member_demographics.sql`.

**Verification:** Apply with the repository's Supabase migration workflow if configured; otherwise inspect the complete SQL and run the available migration/schema check. Confirm `git diff` includes only the new migration and intended files.

### Task 2: Admin member detail trainer cards

**Files:**
- Modify: `admin/src/features/members/pages/MemberDetailPage.tsx`

**Interfaces:**
- Replaces `trainerAssignment` (single row) with `trainerAssignments` (array of active assignment rows and trainer profiles).

- [ ] Change the React Query selection to fetch all active assignments for this member, ordered consistently by `assigned_at`.
- [ ] Render one responsive card per active trainer in the Info tab, link each to `/trainers/:trainerId`, use the existing glass/foreground tokens, and show a useful empty state when none are assigned.
- [ ] Remove the Health Background Screening section and only the now-unused state/imports/query/save handlers that exclusively served this section. Keep screening enrollment flows and data untouched.
- [ ] Confirm TypeScript types remain accurate and that info content still lays out correctly with one or five trainers.

**Verification:** Run `npm run build --prefix admin` after the task; inspect the member details render and type errors.

### Task 3: Admin trainer assignment capacity

**Files:**
- Modify: `admin/src/features/trainers/pages/TrainerDetailPage.tsx`
- Modify: `admin/server/index.js`

**Interfaces:**
- Assignment API retains `POST /api/assign-trainer` with `{ trainer_id, member_id }`; capacity errors return HTTP 409 with a user-readable error.

- [ ] Change the Assign Member chooser so a member already assigned to other trainers is eligible when they have fewer than five active assignments, but is excluded if already active with this trainer.
- [ ] Include the active assignment count in the chooser data and disable members already at five with clear capacity text.
- [ ] Validate capacity and duplicate active assignment in `/api/assign-trainer` before insert for fast feedback; map trigger error `MEMBER_TRAINER_LIMIT_REACHED` to HTTP 409 and a clear message.
- [ ] Keep the database trigger authoritative to handle concurrent requests and non-admin callers.
- [ ] Preserve unassign behavior and invalidate trainer/member assignment queries after successful changes.

**Verification:** Run `npm run build --prefix admin`; inspect endpoint response/error handling and assignment query semantics.

### Task 4: Flutter trainer list and per-trainer chat

**Files:**
- Modify: `mobile/fitness_app/lib/app/router.dart`
- Modify: `mobile/fitness_app/lib/features/member/chat/pages/chat_page.dart`
- Create or modify: `mobile/fitness_app/lib/features/member/chat/pages/member_trainer_list_page.dart`
- Reuse: `mobile/fitness_app/lib/features/trainer/chat/pages/chat_list_page.dart` visual patterns, `mobile/fitness_app/lib/features/shared/widgets/glass_card.dart`, and `app/design_tokens.dart`.

**Interfaces:**
- `/member/chat` renders the member trainer list.
- A nested route `/member/chat/:trainerId` renders the chat room for that active trainer, with the selected trainer ID passed explicitly to `ChatPage`.
- The list queries all active assignments for the authenticated member and trainer profile records; it does not create rooms.

- [ ] Extract/update the member chat provider so it accepts a trainer ID and resolves that trainer, assignment timestamp, and existing room.
- [ ] Route member chat navigation to the trainer list and add a chat detail route for a selected trainer.
- [ ] Add member trainer cards using the trainer conversation list's glass styling, loading/error/empty state conventions, avatar, and search behavior if appropriate.
- [ ] Keep create-room-on-first-message, real-time subscription, and assignment cutoff for the selected trainer only.
- [ ] Make the member chat body and message/composer surfaces readable in both themes while matching the trainer chat screen's visual language.

**Verification:** Run `flutter analyze` from `mobile/fitness_app`; inspect routes for back navigation and confirm list selection passes the correct trainer ID.

### Task 5: Flutter plan repository and shared selected-plan state

**Files:**
- Modify: `mobile/fitness_app/lib/features/trainer/set_plan/data/plan_repository.dart`
- Modify: `mobile/fitness_app/lib/features/trainer/set_plan/pages/create_plan_screen.dart`
- Modify: `mobile/fitness_app/lib/features/shared/providers/plan_providers.dart`
- Modify: `mobile/fitness_app/lib/features/shared/widgets/plan_floating_logo.dart` only if needed to bind visibility to displayed-plan state.

**Interfaces:**
- `Future<List<Map<String, dynamic>>> getMemberPlans(String memberId, {bool displayedOnly = false})` returns eligible plans with trainer name and display state.
- `Future<void> setMemberPlanDisplayed({required String planId, required bool displayed})` calls the safe database RPC.
- Shared provider exposes all displayed plans plus a persisted selected plan ID, and resolves the selected plan with a deterministic fallback.

- [ ] Replace or supplement the single-plan repository method with a list query that includes each plan's trainer profile, status, date window, and `is_displayed`.
- [ ] Make trainer plan availability checks and replacement operations pair-scoped by `member_id` and authenticated `trainer_id`; only cancel that trainer's active row before inserting a replacement.
- [ ] Keep plan creation as a fresh row so old completion rows stay attached to their original `plan_id`; do not reset or cancel another trainer's plan.
- [ ] Implement the `set_member_plan_displayed` RPC call and invalidate displayed/active plan providers after success.
- [ ] Add shared selected-plan state backed by `SharedPreferences`; choose the stored plan if still displayed and in range, otherwise select the first eligible displayed plan or null.
- [ ] Keep completion queries and saves filtered by the selected plan ID, and preserve the existing plan overlay's completion merging behavior.
- [ ] Update floating-logo visibility so no logo appears when there are no displayed eligible plans.

**Verification:** Run `flutter analyze`; inspect plan creation and provider flows for member/trainer scoping, fallback behavior, and plan-ID completion isolation.

### Task 6: Member trainer plan list, detail display control, and workout/food selector

**Files:**
- Modify: `mobile/fitness_app/lib/app/router.dart`
- Modify: `mobile/fitness_app/lib/features/trainer/set_plan/pages/record_detail_screen.dart`
- Create or modify: `mobile/fitness_app/lib/features/member/settings/pages/member_trainer_plan_list_page.dart`
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
- Modify: `mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart`
- Modify: `mobile/fitness_app/lib/features/shared/widgets/trainer_plan_overlay.dart`
- Reuse: `mobile/fitness_app/lib/features/shared/widgets/glass_confirm_dialog.dart`, `glass_card.dart`, and existing theme tokens.

**Interfaces:**
- `/member/trainer-plan` renders active trainers; `/member/trainer-plan/:trainerId` shows that trainer's plan or empty state.
- Plan detail accepts an optional plan ID/trainer ID to select the member/trainer-specific current plan while trainer record routes retain their existing behavior.
- Workout and Food Intake read the same shared displayed-plan list and selected plan ID.

- [ ] Change member Trainer Plan routing to show active trainer cards first and open a trainer-specific plan detail on selection.
- [ ] Preserve the current trainer record detail layout, cancellation request, Workout/Foods tabs, and completion UI; ensure the member view loads only the selected trainer's plan.
- [ ] Add Display/Remove control. Display opens a dark glass/light surface confirmation with Continue and Cancel; Continue calls the display RPC. Remove toggles only that plan off. Use the requested theme-aware purple button label contrast.
- [ ] Add trainer identity and a dropdown selector at the top of each Workout and Food Intake trainer-plan overlay/day sheet when multiple plans are displayed; show identity when only one is displayed.
- [ ] Have each screen open its overlay with the shared selected plan ID; changing the selector updates shared state so navigating to the other screen retains the trainer choice.
- [ ] Ensure removing, cancelling, expiring, or losing access to the selected plan chooses a valid fallback or removes the logo and selector.
- [ ] Check narrow layouts, hit targets, loading/error/empty states, and light/dark contrast against existing glass and Clay patterns.

**Verification:** Run `flutter analyze` and `npm run build --prefix admin`; review the member flow in the app if an existing emulator/browser setup is available. Do not add or run tests unless requested.

### Task 7: Cross-surface review and completion

**Files:**
- Review the changes and migration from Tasks 1–6.

- [ ] Re-read the approved spec and check each acceptance criterion against the implementation.
- [ ] Run the final admin build and Flutter static analysis fresh, recording command exit codes.
- [ ] Review `git diff --check`, changed-file list, and SQL/RPC authorization paths; confirm the pre-existing edit to migration `0050` remains untouched.
- [ ] Summarize changed behavior, verification evidence, and any deployment requirement for applying migration `0052`.

**Commit policy:** Make small commits at safe boundaries only after reviewing the exact staged diff. Do not stage or commit the user's existing edit to migration `0050`.
