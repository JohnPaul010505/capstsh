# Member Detail Logs — Exercise names, real data, stable table size

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Member Details Workout Log shows the real exercise name per row ("-" only when truly absent, never "Workout S1"), missing videos show "-", and both tables render at the same stable size with no first-login shrink and no modal zoom animation.

**Architecture:** One file changed (`admin/src/features/members/pages/MemberDetailPage.tsx` + `admin/src/types/index.ts` if a column is missing). Exercise column prefers `exercise_name`, falls back to `workout_name` only for legacy session-proof rows, Proof column renders Watch/- with no animation classes. Table-size fix: freeze PeopleTable chrome (no size animation on search/table wrapper), keep `useFitRowHeight` target rows stable.

**Tech Stack:** React + TanStack Query + Supabase (`workout_logs`, `meal_logs`), existing `PeopleTable`/`PaginationFooter`/`useFitRowHeight`.

**Spec:** This plan IS the spec (user screenshots + text, 2026-10-10). No separate spec doc.

## Global Constraints

- Admin root: `c:\capstsh\admin`.
- Real member data only — no mock/fallback exercise names.
- No animation on table open or Watch/photo modal open (plain mount, opacity-only backdrop if any).
- `npx tsc --noEmit` clean + `npm run build` passes before commit.

## Review Focus

- Rows where BOTH exercise_name and workout_name are null still render "-" (never blank).
- Session-proof rows (`exercise_name='Session Proof'`) keep old label, never blank.
- Search filter still matches both exercise_name and workout_name.
- Modal has no scale/transition classes anywhere in its tree.
- First-login small-table regression stays fixed (no `animate-*`/size transition reintroduced).
