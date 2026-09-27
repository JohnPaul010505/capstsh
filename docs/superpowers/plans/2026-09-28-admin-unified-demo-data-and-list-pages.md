# Admin Unified Demo Data + Full-Screen List Pages Implementation Plan

> **Goal:** Create one unified, coherent dataset across the entire admin system (987 members, 89 trainers, 1 admin, ~22k attendance rows from Jan 1 2020 to today) and redesign Dashboard, Members, Trainers, and Memberships pages to remove top KPI cards, eliminate scrolling, add client-side/server-side numbered pagination, live search by name AND member code, and date-range calendar filtering.

- **Architecture:** Single Supabase DB dataset (`@demo.fit` namespace alongside existing `@mock.fit` seeds). PostgREST-safe paged fetches (`fetchAll` cap raised from 10 to 40 pages). Server-side filtering + pagination for list pages. Pinned-height viewport layout (`h-full min-h-0 flex-col`) with dynamic row fit (`useFitRows`) preventing any scrollbar.
- **Tech Stack:** React 19, Vite, TanStack Query v5, Tailwind CSS v4, Supabase JS v2, Lucide React, Playwright.

---

## Plan Checklist

### Phase 0: Baseline Ground Truth & Screenshots
- [ ] Task 1: Create `admin/scripts/verify-demo-data.mjs` and capture baseline DB counts + before screenshots.

### Phase 1: Unified Seed Engine & DB Scaled Dataset
- [ ] Task 2: Core seed engine + bulk auth creator (`admin/scripts/seed-demo-scale.mjs`, resumable, concurrency 4, deterministic UUIDs/mulberry32).
- [ ] Task 3: Attendance generator (Jan 1 2020 -> today, ramp 3->24/day, 96% member / 4% trainer, covering memberships).
- [ ] Task 4: Memberships generator (Daily 60 / Monthly 1,800, active/expired/trial).
- [ ] Task 5: Trainer assignments, coach feedback, predictions (0030/0032 compliant), notifications, renewal requests.
- [ ] Task 6: Enrollments (exactly 10 pending + 45 confirmed), migration 0034 scale indexes, reassign and delete extra admin A002.

### Phase 2: Data Fetching Layer (PostgREST 1,000-Row Cap & Scale Proofing)
- [ ] Task 7: Update `fetchAll.ts` (MAX_PAGES 10 -> 40) and paginate `fetchMemberships`/`fetchLastCheckins`.
- [ ] Task 8: Server-side paging, search (name & code), and date-range hooks for members, trainers, memberships.
- [ ] Task 9: Fix remaining 1,000-row capped readers (`useAttendance`, `useMembersSimple`/`MemberSelect`, `InactiveReportPage`).

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
