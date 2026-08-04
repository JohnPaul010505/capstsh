-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- Custom types
create type user_role as enum ('admin', 'trainer', 'member');
create type membership_status as enum ('active', 'expired', 'cancelled');
create type assignment_status as enum ('active', 'ended');

-- Profiles (extends auth.users)
create table profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  role user_role not null default 'member',
  full_name text not null,
  email text not null,
  phone text,
  avatar_url text,
  date_of_birth date,
  gender text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Memberships
create table memberships (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  plan_name text not null,
  price decimal(10,2) not null,
  start_date date not null,
  end_date date not null,
  status membership_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trainer assignments
create table trainer_assignments (
  id uuid primary key default uuid_generate_v4(),
  trainer_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  assigned_at timestamptz not null default now(),
  status assignment_status not null default 'active',
  unique(member_id, trainer_id, status)
);

-- Attendance
create table attendance (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  check_in_time timestamptz not null default now(),
  check_in_date date not null default current_date
);

-- Workout logs
create table workout_logs (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  exercise_name text not null,
  sets int,
  reps int,
  weight decimal(10,2),
  duration_minutes int,
  notes text,
  logged_at timestamptz not null default now()
);

-- Body measurements
create table body_measurements (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  weight_kg decimal(5,2),
  height_cm decimal(5,2),
  body_fat_pct decimal(4,1),
  chest_cm decimal(5,2),
  waist_cm decimal(5,2),
  hips_cm decimal(5,2),
  arm_cm decimal(5,2),
  thigh_cm decimal(5,2),
  measured_at timestamptz not null default now()
);

-- Goals
create table goals (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  description text,
  target_value decimal(10,2),
  current_value decimal(10,2) default 0,
  unit text,
  deadline date,
  status text not null default 'in_progress',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Trainer feedback
create table trainer_feedback (
  id uuid primary key default uuid_generate_v4(),
  trainer_id uuid not null references profiles(id) on delete cascade,
  member_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

-- Meal records
create table meal_records (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  meal_type text not null,
  food_items text not null,
  calories int,
  protein_g decimal(6,2),
  carbs_g decimal(6,2),
  fat_g decimal(6,2),
  recorded_at timestamptz not null default now()
);

-- Food recommendations
create table food_recommendations (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  meal_type text,
  food_name text not null,
  portion_size text,
  reason text,
  created_at timestamptz not null default now()
);

-- Chat rooms
create table chat_rooms (
  id uuid primary key default uuid_generate_v4(),
  participant_one uuid not null references profiles(id) on delete cascade,
  participant_two uuid not null references profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique(participant_one, participant_two)
);

-- Chat messages
create table chat_messages (
  id uuid primary key default uuid_generate_v4(),
  room_id uuid not null references chat_rooms(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  content text not null,
  created_at timestamptz not null default now()
);

-- Notifications
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references profiles(id) on delete cascade,
  title text not null,
  body text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);

-- Predictions
create table predictions (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  metric_name text not null,
  predicted_value decimal(10,2),
  predicted_date date,
  confidence decimal(4,3),
  created_at timestamptz not null default now()
);

-- Admin logs
create table admin_logs (
  id uuid primary key default uuid_generate_v4(),
  admin_id uuid not null references profiles(id) on delete cascade,
  action text not null,
  target_type text,
  target_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

-- Indexes
create index idx_profiles_role on profiles(role);
create index idx_attendance_date on attendance(check_in_date);
create index idx_workout_logs_member on workout_logs(member_id);
create index idx_goals_member on goals(member_id);
create index idx_memberships_member on memberships(member_id);
create index idx_trainer_assignments_trainer on trainer_assignments(trainer_id);
create index idx_trainer_assignments_member on trainer_assignments(member_id);
create index idx_chat_messages_room on chat_messages(room_id);
create index idx_notifications_user on notifications(user_id);
create index idx_predictions_member on predictions(member_id);

-- RLS: Enable on all tables
alter table profiles enable row level security;
alter table memberships enable row level security;
alter table trainer_assignments enable row level security;
alter table attendance enable row level security;
alter table workout_logs enable row level security;
alter table body_measurements enable row level security;
alter table goals enable row level security;
alter table trainer_feedback enable row level security;
alter table meal_records enable row level security;
alter table food_recommendations enable row level security;
alter table chat_rooms enable row level security;
alter table chat_messages enable row level security;
alter table notifications enable row level security;
alter table predictions enable row level security;
alter table admin_logs enable row level security;

-- RLS Policies: Admin profiles
create policy "Admins can read all profiles"
  on profiles for select
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins can insert profiles"
  on profiles for insert
  with check (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins can update all profiles"
  on profiles for update
  using (auth.uid() in (select id from profiles where role = 'admin'));

-- RLS: Admins can do everything on all data tables
create policy "Admins all access"
  on memberships for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on trainer_assignments for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on attendance for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on workout_logs for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on body_measurements for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on goals for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on trainer_feedback for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on meal_records for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on food_recommendations for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on chat_rooms for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on chat_messages for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on notifications for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on predictions for all
  using (auth.uid() in (select id from profiles where role = 'admin'));

create policy "Admins all access"
  on admin_logs for all
  using (auth.uid() in (select id from profiles where role = 'admin'));
