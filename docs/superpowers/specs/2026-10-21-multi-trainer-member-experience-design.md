# Multi-trainer member experience design

## Status

Approved in chat on 2026-10-21. This design is for the capstsh admin web app, Flutter member app, and Supabase schema.

## Goal

Let a member work with up to five active trainers without one trainer's chat or plan replacing another's. Members can browse each trainer's chat and plan, choose which trainer plans appear on their Workout and Food Intake screens, and switch between those displayed plans. Keep the admin member detail screen useful and visually consistent in both theme modes.

## Current behavior

- The admin member Info tab queries one active `trainer_assignments` row with `maybeSingle()` and renders one Assigned Trainer card. It also renders the Health Background Screening section.
- The member Chat route opens `ChatPage`, which resolves only the latest active assignment and opens that trainer's room.
- The member Trainer Plan route opens `RecordDetailScreen` for the member. `PlanRepository.getPlanByMember` and the plan overlay providers resolve one plan.
- `PlanRepository.assignPlan` and the trainer plan creation screen find a plan by member ID, so a second trainer can overwrite the first trainer's plan.
- Workout and Food Intake show a floating plan control backed by one active-plan provider.
- `trainer_assignments` already has assignment status and history; active rows are the member's current trainer relationships.

## Requirements and decisions

### Admin member details

- Remove the Health Background Screening section from the admin member Info tab. Do not remove enrollment screening capture or its stored responses.
- Replace the single active trainer query with a query for all active assignments for the member, including each trainer's profile details.
- Render assigned trainers as a responsive horizontal row of cards, wrapping on narrow layouts. Show only assigned trainers; do not render empty placeholders. The database limit keeps this row at five or fewer cards.
- Keep the section in the Info tab and link each card to the corresponding trainer detail page.

### Active trainer limit

- A member may have at most five active trainer assignments. Inactive historical assignments do not count.
- Enforce the rule at the database boundary so every caller is covered. Add a clear client/server validation in the admin Assign Member flow for immediate feedback; handle a database rejection gracefully in case two assignments race.
- Update the trainer-side Assign Member chooser: allow members who are already assigned to other trainers if they have fewer than five active assignments, while excluding members already actively assigned to the current trainer.
- Preserve assignment history and existing assignment status semantics.

### Member chat

- The Chat navigation item opens a trainer list based on the member's active assignments.
- Selecting a trainer opens the existing conversation behavior for that specific trainer, including room creation on first message, live message updates, and the existing assignment cutoff that hides messages from before the current assignment.
- Preserve each trainer's separate chat room. Do not create rooms just by showing the list.
- Match the trainer chat room's visual language and maintain readable light and dark themes using the current app background, glass surfaces, and shared tokens.

### Member Trainer Plan

- The Trainer Plan entry opens a list of the member's active trainers. Trainers without a plan remain selectable and show a clear empty state.
- Selecting a trainer opens that trainer's current plan detail. Preserve the existing Workout/Foods tabs, completion indicators, and cancellation request flow.
- Add a contextual action on the plan detail: **Display** when the plan is not displayed and **Remove** when it is displayed. For Display, ask for confirmation with Continue and Cancel actions. Continue enables display; Cancel makes no change. Remove immediately disables display (with an appropriate confirmation only if existing app conventions require one).
- Use a white label on purple in dark mode and a dark label on purple in light mode, with contrast consistent with the rest of the app.
- Style the confirmation surface with the existing glass dialog/card components in dark mode and the established light surface in light mode.

### Multiple plans and display selection

- Store one current plan per member/trainer pair. Updating/replacing a trainer's plan updates or cancels only that trainer's current row, while another trainer's row remains intact. In particular, the existing replace-plan action must not cancel other trainers' plans. Preserve existing plan completion relations for the row being updated according to current behavior; do not rewrite unrelated trainers' completions.
- Add a `is_displayed` boolean to `member_goal_plans`, default false for existing rows. The member controls this flag only for their own plan rows; trainer plan content and dates remain trainer-controlled. Add narrowly scoped database grants/policies or a dedicated safe database operation so the member cannot alter trainer-authored fields while toggling display.
- When a member chooses Display, set that plan displayed. Multiple trainer plans may be displayed at once. When a member chooses Remove, only that plan is removed from the displayed set.
- Workout and Food Intake show a trainer selector near the top of the plan overlay/day content when one or more displayed current plans exist. The selector contains only displayed plans that have usable plan content and identifies trainers by name. Selecting a trainer switches the plan data in both surfaces.
- If there is exactly one displayed plan, show its trainer identity and plan without requiring a meaningful choice; if multiple are displayed, make the dropdown clear and accessible. If none are displayed, do not show a trainer plan logo or selector.
- Persist the selected displayed plan across Workout and Food Intake navigation, and fall back to another displayed plan (or no selection) if the selected plan is removed, cancelled, expires, or is no longer available.
- Keep completion state isolated by `plan_id`; workout and food completion for one trainer's plan must not mutate another plan's completion data.

### Theme and accessibility

- Follow existing Flutter `AppGlowBackground`, `GlassPanel`/`GlassCard`, Clay tokens, and theme mode checks rather than introducing a separate visual system.
- Admin cards use existing `glass-card` and foreground tokens.
- Keep text contrast, keyboard/tap targets, back navigation, loading states, and empty states consistent with existing screens.
- Verify the updated flows in both light and dark themes and on narrow phone widths and the admin desktop layout.

## Data and access design

- Add a Supabase migration for the plan display flag and safe member-owned display updates.
- Add a database-side guard for no more than five active assignments per member, using a concurrency-safe transaction-level check (trigger/locking or equivalent). It must ignore rows transitioning to inactive and must preserve the existing unique constraint semantics.
- Update plan writes, replace actions, and active-plan checks to target the member/trainer pair, not member ID alone. The migration should not add a uniqueness constraint that erases plan history assumptions without first checking deployed data; treat the trainer's active plan row as current and preserve cancelled rows as history.
- Member plan reads should return all relevant plans and trainer names; all member writes must remain scoped to `auth.uid() = member_id` and the display flag only.
- Existing rows default to not displayed. Since current behavior implicitly displays the one active plan, migration/backfill should mark the currently active plan for a member displayed where unambiguous, preserving the current experience after upgrade. If multiple historical active rows exist, select the most recent eligible current plan for that member; leave other rows undisplayed.

## Failure handling

- Assignment validation errors should explain the five-trainer maximum and keep the assignment form usable.
- A failed display toggle should leave the prior state visible and offer a retry message.
- Empty assignments, missing profiles, missing plans, missing chat rooms, and query failures should have explicit empty/error states rather than throwing.
- If required Supabase migration is not deployed, data operations should surface a migration-related error instead of silently claiming success.

## Acceptance criteria

1. Admin member Info no longer displays Health Background Screening and displays all active trainer cards up to five.
2. The sixth active trainer assignment is rejected at the database boundary and is clearly explained in the admin assignment flow; inactive history does not block a new assignment.
3. Member Chat opens an assigned-trainer list; each selected trainer leads to the correct independent chat, retaining room creation and real-time behavior.
4. Member Trainer Plan opens an assigned-trainer list and each trainer detail shows only that trainer's plan or an empty state.
5. A member can Display and Remove each trainer's plan independently, with confirmation on Display.
6. Displayed plans are selectable on Workout and Food Intake, and changing the selection changes the plan shown on both screens. Removed plans stop appearing there.
7. Plan completion and cancellation remain associated with the selected plan/trainer.
8. Admin and member UI remain readable and consistent in light and dark mode, including empty/loading/error states.

## Scope boundaries

- No redesign of trainer plan authoring, trainer chat, enrollment screening, or unrelated member profile data.
- No changes to trainer assignment capacity per trainer; the five-plan cap applies to active trainers per member.
- Existing plan detail cancellation workflow remains a request to the trainer, not an immediate cancellation.

## Implementation planning notes

The implementation plan should inspect all active assignment entry points and all queries that assume one assignment or one plan per member, including admin assignment API/server handling, Flutter plan creation, `getPlanByMember`, plan overlay providers, floating logo visibility, Workout, Food Intake, chat routes, and cancellation/completion records. Include migration ordering and a backfill that preserves the existing single-plan experience.
