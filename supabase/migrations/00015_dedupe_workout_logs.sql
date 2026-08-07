-- Fix duplicate workout_logs: the mobile app used to re-persist completed
-- exercises on every app background / restart, inserting duplicate rows.
-- 1) Dedupe existing rows (keep the earliest id per member + exercise + timestamp).
-- 2) Add a unique constraint so future duplicates are rejected at the DB level.

begin;

-- Deduplicate: delete all but the earliest row for each (member_id, exercise_name, logged_at).
delete from workout_logs a
using workout_logs b
where a.id > b.id
  and a.member_id = b.member_id
  and a.exercise_name = b.exercise_name
  and a.logged_at = b.logged_at;

-- Guard against future duplicates.
alter table workout_logs
  add constraint workout_logs_member_exercise_time_unique
  unique (member_id, exercise_name, logged_at);

commit;
