-- Support member-selected trainer plan display and up to five active trainers.

alter table public.member_goal_plans
  add column if not exists is_displayed boolean not null default false;

-- Preserve the previous single-current-plan experience by displaying the most
-- recent plan that is active for each member today. All other rows remain off.
with ranked_current_plans as (
  select
    id,
    row_number() over (
      partition by member_id
      order by start_date desc, created_at desc, id desc
    ) as row_number
  from public.member_goal_plans
  where status = 'active'
    and start_date <= current_date
    and end_date >= current_date
)
update public.member_goal_plans as plan
set is_displayed = true
from ranked_current_plans as ranked
where ranked.id = plan.id
  and ranked.row_number = 1;

-- Members can change only the display state of a plan they own. The function
-- bypasses table RLS deliberately, so its ownership predicate is the complete
-- write boundary.
create or replace function public.set_member_plan_displayed(
  p_plan_id uuid,
  p_is_displayed boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception using
      errcode = '42501',
      message = 'AUTHENTICATION_REQUIRED';
  end if;

  update public.member_goal_plans
  set is_displayed = p_is_displayed
  where id = p_plan_id
    and member_id = auth.uid();

  if not found then
    raise exception using
      errcode = '42501',
      message = 'PLAN_NOT_OWNED';
  end if;
end;
$$;

revoke execute on function public.set_member_plan_displayed(uuid, boolean) from public;
revoke execute on function public.set_member_plan_displayed(uuid, boolean) from anon;
grant execute on function public.set_member_plan_displayed(uuid, boolean) to authenticated;

-- Serialize active-assignment changes per member, then reject a sixth active
-- row. The existing unique(member_id, trainer_id, status) constraint remains
-- responsible for duplicate active assignments for a trainer/member pair.
create or replace function public.enforce_member_active_trainer_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  active_assignment_count integer;
begin
  -- Inactive rows never contribute to the per-member active trainer limit.
  if new.status <> 'active' then
    return new;
  end if;

  perform pg_advisory_xact_lock(hashtextextended(new.member_id::text, 0));

  select count(*)
  into active_assignment_count
  from public.trainer_assignments as assignment
  where assignment.member_id = new.member_id
    and assignment.status = 'active'
    and assignment.id is distinct from new.id;

  if active_assignment_count >= 5 then
    raise exception using
      errcode = 'P0001',
      message = 'MEMBER_TRAINER_LIMIT_REACHED';
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_member_active_trainer_limit
  on public.trainer_assignments;
create trigger trg_enforce_member_active_trainer_limit
  before insert or update of member_id, trainer_id, status
  on public.trainer_assignments
  for each row
  execute function public.enforce_member_active_trainer_limit();
