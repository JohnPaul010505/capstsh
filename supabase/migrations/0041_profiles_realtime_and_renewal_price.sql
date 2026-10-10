-- 0041_profiles_realtime_and_renewal_price.sql
--
-- Two things the admin panel needs to be live instead of reload-to-see:
--
--   1. `profiles` (plus `memberships` / `membership_renewal_requests`) in the
--      `supabase_realtime` publication. When an admin edits a member's phone,
--      email or a trainer's specialty, the mobile app and every open admin tab
--      must move with it. 0039 only published chat_messages, attendance,
--      workout_logs and meal_logs, so `.stream()` on `profiles` failed with
--      "Unable to subscribe to changes ... Please check Realtime is enabled".
--
--   2. The money on a renewal. Approving a request used to guess the price from
--      the plan table or the previous membership; the admin now states the
--      amount actually collected, which is what the Revenue tab sums.
--
-- Idempotent: safe to re-run.
--
-- Apply with the Supabase SQL editor, or:
--   supabase db push

do $$
declare
  t text;
begin
  foreach t in array array[
    'profiles',
    'memberships',
    'membership_renewal_requests'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

alter table membership_renewal_requests
  add column if not exists requested_price numeric(10,2),
  add column if not exists approved_price numeric(10,2);

comment on column membership_renewal_requests.requested_price is
  'Amount the member says they were quoted when applying (optional).';
comment on column membership_renewal_requests.approved_price is
  'Amount the admin actually collected on approval; the membership row is '
  'created at this price, so the dashboard Revenue tab follows it.';

-- Realtime also needs REPLICA IDENTITY FULL for UPDATE payloads to carry the
-- old row; the default (primary key) is enough for "this row changed", which is
-- all the profile sync needs, so no extra alter here.
