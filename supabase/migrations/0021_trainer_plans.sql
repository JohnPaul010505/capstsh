-- Trainer 7-day plan support
-- member_goal_plans: stores the plan assigned by a trainer to a member
-- plan_day_completions: stores per-day completion state for exercises and foods

-- member_goal_plans
create table if not exists member_goal_plans (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references profiles(id) on delete cascade,
  trainer_id uuid not null references profiles(id) on delete cascade,
  start_date date not null,
  end_date date not null,
  timeframe text not null default '7_days',
  notes text,
  food_plan jsonb not null default '[]'::jsonb,
  exercise_plan jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_member_goal_plans_member on member_goal_plans(member_id);
create index if not exists idx_member_goal_plans_trainer on member_goal_plans(trainer_id);

-- plan_day_completions
create table if not exists plan_day_completions (
  id uuid primary key default gen_random_uuid(),
  plan_id uuid not null references member_goal_plans(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  day_number int not null check (day_number between 1 and 7),
  date date not null,
  completed_exercises jsonb not null default '[]'::jsonb,
  completed_foods jsonb not null default '[]'::jsonb,
  is_complete boolean not null default false,
  notified_member boolean not null default false,
  notified_trainer boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(plan_id, member_id, day_number)
);

create index if not exists idx_plan_day_completions_member on plan_day_completions(member_id);
create index if not exists idx_plan_day_completions_plan on plan_day_completions(plan_id);

-- RLS
alter table member_goal_plans enable row level security;
alter table plan_day_completions enable row level security;

-- member_goal_plans policies
drop policy if exists "Trainers can read own plans" on member_goal_plans;
create policy "Trainers can read own plans"
  on member_goal_plans for select
  using (auth.uid() = trainer_id);

drop policy if exists "Trainers can insert plans" on member_goal_plans;
create policy "Trainers can insert plans"
  on member_goal_plans for insert
  with check (auth.uid() = trainer_id);

drop policy if exists "Trainers can update own plans" on member_goal_plans;
create policy "Trainers can update own plans"
  on member_goal_plans for update
  using (auth.uid() = trainer_id);

drop policy if exists "Members can read own plans" on member_goal_plans;
create policy "Members can read own plans"
  on member_goal_plans for select
  using (auth.uid() = member_id);

drop policy if exists "Admins all access member_goal_plans" on member_goal_plans;
create policy "Admins all access member_goal_plans"
  on member_goal_plans for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

-- plan_day_completions policies
drop policy if exists "Members can read own completions" on plan_day_completions;
create policy "Members can read own completions"
  on plan_day_completions for select
  using (auth.uid() = member_id);

drop policy if exists "Members can update own completions" on plan_day_completions;
create policy "Members can update own completions"
  on plan_day_completions for update
  using (auth.uid() = member_id);

drop policy if exists "Members can insert own completions" on plan_day_completions;
create policy "Members can insert own completions"
  on plan_day_completions for insert
  with check (auth.uid() = member_id);

drop policy if exists "Trainers can read assigned member completions" on plan_day_completions;
create policy "Trainers can read assigned member completions"
  on plan_day_completions for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = plan_day_completions.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );

drop policy if exists "Admins all access plan_day_completions" on plan_day_completions;
create policy "Admins all access plan_day_completions"
  on plan_day_completions for all
  using (auth.uid() in (select id from profiles where role = 'admin'));