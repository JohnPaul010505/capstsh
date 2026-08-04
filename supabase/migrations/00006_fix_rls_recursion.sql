-- Fix RLS infinite recursion on profiles
-- Creates a security definer function to check admin role without recursion

create or replace function public.is_admin()
returns boolean
language sql
security definer
stable
as $$
  select exists (select 1 from profiles where id = auth.uid() and role = 'admin');
$$;

-- Recreate admin policies on profiles to use the function
drop policy if exists "Admins can read all profiles" on profiles;
create policy "Admins can read all profiles"
  on profiles for select
  using (public.is_admin());

drop policy if exists "Admins can insert profiles" on profiles;
create policy "Admins can insert profiles"
  on profiles for insert
  with check (public.is_admin());

drop policy if exists "Admins can update all profiles" on profiles;
create policy "Admins can update all profiles"
  on profiles for update
  using (public.is_admin());

-- Recreate admin all-access policies on data tables
drop policy if exists "Admins all access" on memberships;
create policy "Admins all access" on memberships for all using (public.is_admin());

drop policy if exists "Admins all access" on trainer_assignments;
create policy "Admins all access" on trainer_assignments for all using (public.is_admin());

drop policy if exists "Admins all access" on attendance;
create policy "Admins all access" on attendance for all using (public.is_admin());

drop policy if exists "Admins all access" on workout_logs;
create policy "Admins all access" on workout_logs for all using (public.is_admin());

drop policy if exists "Admins all access" on body_measurements;
create policy "Admins all access" on body_measurements for all using (public.is_admin());

drop policy if exists "Admins all access" on goals;
create policy "Admins all access" on goals for all using (public.is_admin());

drop policy if exists "Admins all access" on trainer_feedback;
create policy "Admins all access" on trainer_feedback for all using (public.is_admin());

drop policy if exists "Admins all access" on meal_records;
create policy "Admins all access" on meal_records for all using (public.is_admin());

drop policy if exists "Admins all access" on food_recommendations;
create policy "Admins all access" on food_recommendations for all using (public.is_admin());

drop policy if exists "Admins all access" on chat_rooms;
create policy "Admins all access" on chat_rooms for all using (public.is_admin());

drop policy if exists "Admins all access" on chat_messages;
create policy "Admins all access" on chat_messages for all using (public.is_admin());

drop policy if exists "Admins all access" on notifications;
create policy "Admins all access" on notifications for all using (public.is_admin());

drop policy if exists "Admins all access" on predictions;
create policy "Admins all access" on predictions for all using (public.is_admin());

drop policy if exists "Admins all access" on admin_logs;
create policy "Admins all access" on admin_logs for all using (public.is_admin());

-- Also fix admin check_ins and meal_logs policies from migration 00003
drop policy if exists "Admins all access check_ins" on check_ins;
create policy "Admins all access check_ins" on check_ins for all using (public.is_admin());

drop policy if exists "Admins all access meal_logs" on meal_logs;
create policy "Admins all access meal_logs" on meal_logs for all using (public.is_admin());

-- Fix enrollments policies from migration 00004
drop policy if exists "Admins can read all enrollments" on enrollments;
create policy "Admins can read all enrollments" on enrollments for select using (public.is_admin());

drop policy if exists "Admins can update enrollments" on enrollments;
create policy "Admins can update enrollments" on enrollments for update using (public.is_admin());
