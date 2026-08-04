-- Create check_ins table (used by Flutter app for member check-in tracking)
create table if not exists check_ins (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references profiles(id) on delete cascade,
  check_in_time timestamptz not null default now()
);

-- Create meal_logs table (used by Flutter app for meal logging)
create table if not exists meal_logs (
  id uuid primary key default gen_random_uuid(),
  member_id uuid not null references profiles(id) on delete cascade,
  meal_type text not null,
  food_name text not null,
  calories int,
  protein_g decimal(6,2),
  carbs_g decimal(6,2),
  fat_g decimal(6,2),
  photo_url text,
  meal_time timestamptz not null default now()
);

-- Indexes
create index if not exists idx_check_ins_member on check_ins(member_id);
create index if not exists idx_check_ins_time on check_ins(check_in_time);
create index if not exists idx_meal_logs_member on meal_logs(member_id);
create index if not exists idx_meal_logs_time on meal_logs(meal_time);

-- Enable RLS
alter table check_ins enable row level security;
alter table meal_logs enable row level security;

-- RLS Policies for check_ins
create policy "Users can read own check_ins"
  on check_ins for select
  using (auth.uid() = member_id);

create policy "Users can insert own check_ins"
  on check_ins for insert
  with check (auth.uid() = member_id);

create policy "Trainers can read assigned member check_ins"
  on check_ins for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = check_ins.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );

create policy "Admins all access check_ins"
  on check_ins for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

-- RLS Policies for meal_logs
create policy "Users can read own meal_logs"
  on meal_logs for select
  using (auth.uid() = member_id);

create policy "Users can insert own meal_logs"
  on meal_logs for insert
  with check (auth.uid() = member_id);

create policy "Users can update own meal_logs"
  on meal_logs for update
  using (auth.uid() = member_id);

create policy "Users can delete own meal_logs"
  on meal_logs for delete
  using (auth.uid() = member_id);

create policy "Trainers can read assigned member meal_logs"
  on meal_logs for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = meal_logs.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );

create policy "Admins all access meal_logs"
  on meal_logs for all
  using (auth.uid() in (select id from profiles where role = 'admin'));
