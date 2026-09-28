-- 0035_scale_indexes.sql
--
-- Indexes for the list pages that now read the full dataset.
--
-- The unified demo seed (plan Tasks 2-6) took attendance from 22k to 42k rows
-- and memberships to 1,860, and Phases 2-5 of that plan replace the old
-- "fetch 1,000 rows and filter in the browser" pattern with server-side paging,
-- search by name/code and date-range filtering. Every one of those operations
-- is a sort or a filter on a column that is currently unindexed, so without
-- this file the redesign turns a fast page into a sequential scan.
--
-- The columns here are exactly the ones the pages order/filter on, taken from
-- the hooks that consume them:
--   * attendance  — the attendance table and the last-check-in join
--   * memberships — the Daily/Monthly/Renewal tabs (plan by status, expiring
--                   panel by end_date, search/sort by member)
--   * trainer_assignments — a trainer detail page's "active members" list
--   * membership_renewal_requests — the renewal queue, filtered by status
--   * trainer_feedback — a member's coaching history
--   * predictions — the recent-forecasts list, newest first
--   * profiles — code search, which the plan adds to both people pages
--
-- IF NOT EXISTS throughout: this file is safe to run more than once.
--
-- Run with CREATE INDEX CONCURRENTLY where the table is large enough to matter,
-- because a plain CREATE INDEX takes an ACCESS EXCLUSIVE lock and blocks reads
-- for the duration. CONCURRENTLY cannot run inside a transaction block, so run
-- this script in the Supabase SQL editor as its own statement batch.

-- --- attendance ------------------------------------------------------------
-- The per-member coverage read that drives every "last check-in" column and
-- the member detail page's calendar.
create index if not exists idx_attendance_member_time
  on attendance (member_id, check_in_time desc);
-- NOTE: 00001 already created idx_attendance_date on attendance(check_in_date).
-- A btree can be scanned backwards, so the date-range filter and the
-- newest-first ordering are both served by it. Not recreated here.

-- --- memberships -----------------------------------------------------------
-- The list pages filter by plan and sort/filter by the end date (the expiring
-- panel is `status = 'active' and end_date <= now() + 30 days`).
create index if not exists idx_memberships_status_end
  on memberships (status, end_date);
-- 00001 has idx_memberships_member on (member_id) alone. The membership
-- history view needs member_id + start_date together, so this is a separate
-- composite under a distinct name — reusing the old name would make
-- IF NOT EXISTS a silent no-op and leave the weak index in place.
create index if not exists idx_memberships_member_start
  on memberships (member_id, start_date desc);

-- --- coaching --------------------------------------------------------------
-- TrainerDetailPage lists a trainer's assignments; FeedbackTable lists a
-- member's notes newest first. 00001 indexes these tables' foreign keys
-- individually, so these composites add the status/date the pages filter on.
create index if not exists idx_trainer_assignments_trainer_status
  on trainer_assignments (trainer_id, status);
create index if not exists idx_trainer_assignments_member_status
  on trainer_assignments (member_id, status);
create index if not exists idx_trainer_feedback_member
  on trainer_feedback (member_id, created_at desc);

-- --- front desk ------------------------------------------------------------
-- The renewal queue and the enrollment queue are both "filter by status,
-- oldest/newest first" with only a handful of rows each, so the index keeps
-- those queries off a full scan as the history grows. 00004 already has
-- idx_enrollments_status on (status) alone.
create index if not exists idx_renewal_requests_status
  on membership_renewal_requests (status, requested_at desc);
create index if not exists idx_enrollments_status_created
  on enrollments (status, created_at desc);

-- --- insights --------------------------------------------------------------
-- usePredictions orders by created_at desc and hides body_fat rows; 00001 has
-- idx_predictions_member on (member_id) alone.
create index if not exists idx_predictions_member_metric
  on predictions (member_id, metric_name, created_at desc);

-- --- people search ---------------------------------------------------------
-- The plan adds search by member code to both list pages. 00009 already
-- created the unique index on profiles(code), so code search is covered.
--
-- Name search is the new requirement, and an equality lookup on full_name
-- cannot serve it. This is a functional index for a case-insensitive prefix
-- match; text_pattern_ops keeps it a plain btree.
create index if not exists idx_profiles_full_name_lower
  on profiles (lower(full_name) text_pattern_ops);
