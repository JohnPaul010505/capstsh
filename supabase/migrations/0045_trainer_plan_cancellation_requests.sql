-- Member requests to stop an active trainer plan. Requests do not cancel the plan;
-- the assigned trainer reviews the request and is notified in-app.
create table if not exists public.trainer_plan_cancellation_requests (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references public.member_goal_plans(id) on delete cascade,
  member_id uuid not null references public.profiles(id) on delete cascade,
  trainer_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'declined')),
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create unique index if not exists trainer_plan_one_pending_cancellation
  on public.trainer_plan_cancellation_requests(plan_id, member_id)
  where status = 'pending';

create index if not exists trainer_plan_cancellation_trainer
  on public.trainer_plan_cancellation_requests(trainer_id, status, created_at desc);

alter table public.trainer_plan_cancellation_requests enable row level security;

drop policy if exists "Members request their own plan cancellation" on public.trainer_plan_cancellation_requests;
create policy "Members request their own plan cancellation"
  on public.trainer_plan_cancellation_requests for insert
  with check (
    auth.uid() = trainer_plan_cancellation_requests.member_id
    and trainer_plan_cancellation_requests.status = 'pending'
    and exists (
      select 1 from public.member_goal_plans p
      where p.id = trainer_plan_cancellation_requests.plan_id
        and p.member_id = trainer_plan_cancellation_requests.member_id
        and p.trainer_id = trainer_plan_cancellation_requests.trainer_id
        and p.status = 'active'
    )
  );

drop policy if exists "Members and trainers read plan cancellation requests" on public.trainer_plan_cancellation_requests;
create policy "Members and trainers read plan cancellation requests"
  on public.trainer_plan_cancellation_requests for select
  using (auth.uid() = member_id or auth.uid() = trainer_id);

drop policy if exists "Trainers review plan cancellation requests" on public.trainer_plan_cancellation_requests;
create policy "Trainers review plan cancellation requests"
  on public.trainer_plan_cancellation_requests for update
  using (auth.uid() = trainer_id)
  with check (auth.uid() = trainer_id);

create or replace function public.notify_trainer_plan_cancellation_request()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  member_name text;
begin
  select full_name into member_name from public.profiles where id = new.member_id;
  insert into public.notifications(user_id, title, body, read)
  values (
    new.trainer_id,
    'Trainer plan cancellation request',
    coalesce(member_name, 'A member') || ' requested to cancel their trainer plan.',
    false
  );
  return new;
end;
$$;

drop trigger if exists trg_notify_trainer_plan_cancellation_request
  on public.trainer_plan_cancellation_requests;
create trigger trg_notify_trainer_plan_cancellation_request
  after insert on public.trainer_plan_cancellation_requests
  for each row execute function public.notify_trainer_plan_cancellation_request();
