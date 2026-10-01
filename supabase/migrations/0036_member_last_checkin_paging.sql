-- member_last_checkin(): page the aggregate.
--
-- Migration 0035 added the function so the Member Overview tab could ask the
-- database for `group by member_id, max(check_in_date)` instead of downloading
-- every attendance row. It works, but it has a silent ceiling:
--
--   POST /rest/v1/rpc/member_last_checkin
--   -> 200, content-range: 0-985/*
--
-- PostgREST applies `db-max-rows` (1,000 here) to RPC responses and IGNORES the
-- Range header on /rpc/ - sending `Range: 0-1046` returns the same 986 rows with
-- the same content-range. So the day the roster passes ~1,000 distinct members
-- with check-ins, the extra members lose their "days since last visit" and the
-- Member Overview tab shows them as never-visited with no error anywhere.
-- Measured against the current dataset it returns 986 of 986, i.e. the bug is
-- latent, not active - which is exactly why it needs a parameter rather than a
-- lucky row count.
--
-- `p_limit` / `p_offset` are the only lever PostgREST honours on an RPC, so the
-- function now takes them. They default to NULL, which returns everything, and
-- keep the 0035 zero-argument call working for any caller that has not migrated.
--
-- Same security posture as 0035: read-only, `security definer`, search_path
-- pinned, execute revoked from public and granted to the two roles that need it.
create or replace function public.member_last_checkin(
  p_limit  integer default null,
  p_offset integer default 0
)
returns table (member_id uuid, last_check_in date)
language sql
stable
security definer
set search_path = public
as $$
  select a.member_id, max(a.check_in_date)::date
  from attendance a
  group by a.member_id
  order by a.member_id
  limit case when p_limit is null then null else greatest(p_limit, 0) end
  offset greatest(coalesce(p_offset, 0), 0);
$$;

revoke execute on function public.member_last_checkin(integer, integer) from public;
grant execute on function public.member_last_checkin(integer, integer) to authenticated, service_role;

-- A total the client can page against without trusting content-range.
create or replace function public.member_last_checkin_count()
returns bigint
language sql
stable
security definer
set search_path = public
as $$
  select count(distinct a.member_id) from attendance a;
$$;

revoke execute on function public.member_last_checkin_count() from public;
grant execute on function public.member_last_checkin_count() to authenticated, service_role;
