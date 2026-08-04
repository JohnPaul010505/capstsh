-- Fix QR check-in: RLS for members and trainers on attendance
drop policy if exists "Users can read own attendance" on attendance;
create policy "Users can read own attendance" on attendance for select
  using (auth.uid() = member_id);

drop policy if exists "Users can insert own attendance" on attendance;
create policy "Users can insert own attendance" on attendance for insert
  with check (auth.uid() = member_id);

drop policy if exists "Users can update own attendance" on attendance;
create policy "Users can update own attendance" on attendance for update
  using (auth.uid() = member_id);

drop policy if exists "Trainers can read assigned member attendance" on attendance;
create policy "Trainers can read assigned member attendance" on attendance for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = attendance.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );

-- Session expiry: open sessions auto-expire 12h after check-in
alter table attendance add column if not exists expires_at timestamptz;

-- check_out_time (from migration 00002 — never applied to this project; required for check-in/out)
alter table attendance add column if not exists check_out_time timestamptz;

-- Inactivity flag for reports (7-day no check-in)
alter table profiles add column if not exists is_active boolean not null default true;

-- Workout video proof
alter table workout_logs add column if not exists proof_url text;
alter table workout_logs add column if not exists proof_type text;

-- Align workout weight column with mobile app inserts (workout_page.dart uses weight_kg)
alter table workout_logs add column if not exists weight_kg decimal(10,2);

-- Feedback allowed without a coach (trainer_id nullable)
alter table trainer_feedback alter column trainer_id drop not null;

-- Storage bucket for workout videos + meal photos
insert into storage.buckets (id, name, public)
values ('proofs', 'proofs', true)
on conflict (id) do nothing;
