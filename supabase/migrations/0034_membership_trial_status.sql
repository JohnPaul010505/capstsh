-- 0034: extend membership_status with 'trial'.
--
-- Task 4 of the admin-unified demo-data plan seeds free trial memberships
-- alongside paid active/expired ones; the baseline enum created in 00001 only
-- has (active, expired, cancelled). No UI reads the 'trial' value yet — the
-- Memberships page derives display status from dates — but demo/report queries
-- filter on status, so trials must not masquerade as 'active'.
--
-- Apply in the Supabase SQL editor (one paste) — same flow as 0033. The
-- memberships seed (admin/scripts/seed/seed-memberships.mjs) probes for this
-- value: before this migration it inserts the 1,800 paid rows, verifies that
-- subset, and exits 0 with a notice; re-run it afterwards to add the 60 trial
-- rows. (Renumbering note: Task 6's planned "0034 scale indexes" migration
-- becomes 0035.)
alter type membership_status add value if not exists 'trial';

-- PostgREST caches DDL/enum metadata; force an immediate schema reload so REST
-- inserts accept the new value without waiting for the cache to expire.
notify pgrst, 'reload schema';
