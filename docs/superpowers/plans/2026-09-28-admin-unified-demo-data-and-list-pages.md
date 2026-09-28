# Admin Unified Demo Data + Full-Screen List Pages Implementation Plan

> **Goal:** Create one unified, coherent dataset across the entire admin system (987 members, 89 trainers, 1 admin, ~22k attendance rows from Jan 1 2020 to today) and redesign Dashboard, Members, Trainers, and Memberships pages to remove top KPI cards, eliminate scrolling, add client-side/server-side numbered pagination, live search by name AND member code, and date-range calendar filtering.

- **Architecture:** Single Supabase DB dataset (`@demo.fit` namespace alongside existing `@mock.fit` seeds). PostgREST-safe paged fetches (`fetchAll` cap raised from 10 to 40 pages). Server-side filtering + pagination for list pages. Pinned-height viewport layout (`h-full min-h-0 flex-col`) with dynamic row fit (`useFitRows`) preventing any scrollbar.
- **Tech Stack:** React 19, Vite, TanStack Query v5, Tailwind CSS v4, Supabase JS v2, Lucide React, Playwright.

---

## Plan Checklist

### Phase 0: Baseline Ground Truth & Screenshots
- [x] Task 1: Create `admin/scripts/verify-demo-data.mjs` and capture baseline DB counts + before screenshots.

### Phase 1: Unified Seed Engine & DB Scaled Dataset
- [x] Task 2: Core seed engine + bulk auth creator (`admin/scripts/seed/seed-users.mjs` + `lib/`, resumable, concurrency 4). DONE 2026-09-28: 987 members / 89 trainers, 0 dupe emails/codes, VERIFY PASSED.
- [x] Task 3: Attendance generator (Jan 1 2020 -> today, ramp 3->24/day, 96% member / 4% trainer, covering memberships). DONE 2026-09-28: 22,064 rows (2020-01-04 → today), 987 members / 89 trainers incl. the 30+7 pre-existing, 3.9% trainer share, Sundays closed, 3–4 open sessions today clamped to the past, VERIFY PASSED. Manifest stores real UTC instants + per-member windows (coverage map for Task 4). RE-SEEDED 2026-09-28 with the regular-attender overlay: 42,141 rows (20,699 overlay), VERIFY PASSED. See Task 5 for why the overlay exists.
- [x] Task 4: Memberships generator (Daily 60 / Monthly 1,800, active/expired/trial). DONE 2026-09-28: 1,860 rows (588 active / 1,212 expired / 60 trial), 987/987 members covered, expiring supply ≤7d 136 / ≤30d 558, date coherence vs asOf clean, VERIFY PASSED + idempotent. `trial` status added by migration 0034 (pasted into SQL editor); seed script `admin/scripts/seed/seed-memberships.mjs` (resumable manifest, enum probe, trials inserted last). RE-SEEDED 2026-09-28 after the attendance overlay changed the windows: 1,860 rows (645 active / 1,155 expired / 60 trial), 0 field mismatches, expiring supply ≤7d 154 / ≤30d 612, VERIFY PASSED. Actives rose because overlay members attend this week.
- [x] Task 5: Trainer assignments, coach feedback, predictions (0030/0032 compliant), notifications, renewal requests. DONE 2026-09-28: 1,192 assignments (1,004 active / 188 ended, 918/918 active members covered) · 1,157 feedback (792 rated, avg 4.12, all 89 trainers) · 346 predictions (26 weight from real weigh-ins / 320 retention risk, bands low 58 / medium 102 / high 160) · 210 renewals (exactly 24 pending / 150 approved / 36 declined) · 841 notifications (631 seeded + 210 auto-created by the 0027 trigger, 9 distinct titles). VERIFY PASSED, re-run inserted 0 rows.
- [x] Task 6: Enrollments (exactly 10 pending + 45 confirmed), migration 0035 scale indexes (0034 taken by the membership `trial` enum), reassign and delete extra admin A002. DONE 2026-09-28: 55 enrollments (exactly 10 pending / 45 confirmed, 55 unique `@demo.fit` emails, no decision on a pending row and every confirmed row decided after it was requested), VERIFY PASSED + idempotent. Admin check is a single row (A001 admin@gmail.com) — A002 never existed, so the "reassign and delete" step is replaced by an assertion (see seed-enrollments.mjs `verifySingleAdmin`). `supabase/migrations/0035_scale_indexes.sql` written: 9 indexes across attendance/memberships/assignments/feedback/renewals/enrollments/predictions/profiles. **NOT YET APPLIED — needs pasting into the Supabase SQL editor** (the plan's blocker; 00001/00004/00009 already cover 4 of the 13, and 0035 deliberately skips those rather than adding no-op same-name indexes).

### Phase 2: Data Fetching Layer (PostgREST 1,000-Row Cap & Scale Proofing)
- [x] Task 7: Update `fetchAll.ts` (MAX_PAGES 10 -> 40) and paginate `fetchMemberships`/`fetchLastCheckins`. DONE 2026-09-28: **MAX_PAGES raised 10 -> 60, not the planned 40** — the overlay took attendance to 42,141 rows, which needs 43 pages, so the plan's 40 (40,000) would still have truncated silently. `fetchMemberships()` was an unpaged `.select()` on the strength of a stale "27 rows today" comment, so it was capped at 1,000 of 1,860 and the dashboard's plan filter was resolving against a truncated history; it now pages with a `start_date, id` tiebreak. Verified: attendance 42,141 fetched / 42,141 unique / 42,141 in DB, memberships 1,860/1,860, lastCheckins covers 1,047 members. `tsc --noEmit` clean.
- [x] Task 8: Server-side paging, search (name & code), and date-range hooks for members, trainers, memberships. DONE 2026-09-28: new `src/lib/pagedTable.ts` (generic `usePagedTable` — server-side page, `count:'exact'` total for the footer, `or()` search, date range, `eq`/`in` predicates, and `useResetPageOnChange`) plus `src/lib/listHooks.ts` (`useMembersList`, `useTrainersList`, `useMembershipsList`, `useMembershipSearchIds`). Every query's `orderBy` ends in a unique tiebreak (`id`) because PostgREST pages by OFFSET and two rows sharing a sort value would otherwise straddle a boundary. Search covers full_name AND code AND email; the term is sanitised because `or=` is a filter mini-language where a typed comma would reshape the filter. Membership search resolves to member ids first, since the joined profile's name cannot join the same `or()`. Verified live by `scripts/verify-list-queries.mjs` — 14 assertions, all pass: total 987, page 1 = 20 rows, page 1/2 disjoint, code search `M034` returns exactly M034, name search `Dela Cruz` returns 32, injection term neither 400s nor widens the filter, Daily total 60 with the profile join populated, date range narrows 1,860 → 1,746, empty `in` list matches nothing. `tsc --noEmit` clean.
- [x] Task 9: Fix remaining 1,000-row capped readers (`useAttendance`, `useMembersSimple`/`MemberSelect`, `InactiveReportPage`). DONE 2026-09-28: `useAttendance` was an unpaged select against 42,141 rows — it silently stopped at 1,000, now paged. `useMembersSimple` sat at 987 members, one row under the cap, now paged. `MemberSelect` is presentational only (no query) — no change needed. `InactiveReportPage`'s selects are bounded (60 Daily memberships, one week of attendance) — no change needed. `usePredictions`' `.limit(50)` is deliberate page design, not a truncation bug.

### Phase 3: Dashboard Redesign (No Top Cards, No Scroll)
- [ ] Task 10: Delete the 4 summary StatsCards (`Total Revenue`, `Total Members`, `Total Trainers`, `Total Attendance`) and dead hooks; reshape DashboardPage to viewport-fitted grid (`min-h-0`, `overflow-hidden`).
- [ ] Task 11: Update `verify-dashboard-tabs.mjs` and verify no-scroll across all 5 dashboard tabs.

### Phase 4: Members & Trainers Redesign (Identical Look, Numbered Pagination, Name/Code Search, Calendar)
- [ ] Task 12: Build shared components: `PaginationFooter.tsx` (numbered `« ‹ 1 2 3 … 66 › »`), `ListToolbar.tsx`, `useFitRows.ts`, `PeopleTable.tsx`.
- [ ] Task 13: Redesign `MembersListPage.tsx` and `TrainersListPage.tsx` with identical full-screen layout, no-scroll, search by name/code, and Joined calendar.

### Phase 5: Memberships Page Redesign (Daily, Monthly, Renewal Tabs Full Screen)
- [ ] Task 14: Redesign `MembershipsPage.tsx` Daily/Monthly/Renewal tabs with full-screen layout, start-date calendar, search, numbered pagination, and delete hardcoded `MOCK_PENDING_RENEWALS`.

### Phase 6: System Sweep & Release Verification
- [ ] Task 15: Verify QR (10 pending), Reports, Feedback, Predictions, Notifications against seeded data.
- [ ] Task 16: End-to-end verification (`npm run build`, `verify-demo-data`, `verify-dashboard-tabs`, `verify-admin-ui`) and summary report.

---
