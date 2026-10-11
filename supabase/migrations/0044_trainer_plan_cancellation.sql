-- Track trainer plan cancellation so cancelled plans stay in records but disappear from member active-plan surfaces.
alter table public.member_goal_plans
  add column if not exists status text not null default 'active';

update public.member_goal_plans set status = 'active' where status is null;
