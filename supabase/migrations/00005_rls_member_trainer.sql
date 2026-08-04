-- RLS Policies for Members and Trainers
-- Idempotent: drops existing policies before creating

-- Profiles
drop policy if exists "Users can read own profile" on profiles;
create policy "Users can read own profile" on profiles for select using (auth.uid() = id);

drop policy if exists "Users can update own profile" on profiles;
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);

drop policy if exists "Trainers can read assigned members" on profiles;
create policy "Trainers can read assigned members" on profiles for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = profiles.id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

drop policy if exists "Members can read assigned trainer" on profiles;
create policy "Members can read assigned trainer" on profiles for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.trainer_id = profiles.id and trainer_assignments.member_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Memberships
drop policy if exists "Users can read own membership" on memberships;
create policy "Users can read own membership" on memberships for select using (auth.uid() = member_id);

drop policy if exists "Trainers can read assigned member memberships" on memberships;
create policy "Trainers can read assigned member memberships" on memberships for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = memberships.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Trainer assignments
drop policy if exists "Users can read own assignments" on trainer_assignments;
create policy "Users can read own assignments" on trainer_assignments for select using (auth.uid() = trainer_id or auth.uid() = member_id);

-- Workout logs
drop policy if exists "Users can read own workout_logs" on workout_logs; drop policy if exists "Users can insert own workout_logs" on workout_logs; drop policy if exists "Users can update own workout_logs" on workout_logs; drop policy if exists "Users can delete own workout_logs" on workout_logs; drop policy if exists "Trainers can read assigned member workout_logs" on workout_logs;
create policy "Users can read own workout_logs" on workout_logs for select using (auth.uid() = member_id);
create policy "Users can insert own workout_logs" on workout_logs for insert with check (auth.uid() = member_id);
create policy "Users can update own workout_logs" on workout_logs for update using (auth.uid() = member_id);
create policy "Users can delete own workout_logs" on workout_logs for delete using (auth.uid() = member_id);
create policy "Trainers can read assigned member workout_logs" on workout_logs for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = workout_logs.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Body measurements
drop policy if exists "Users can read own body_measurements" on body_measurements; drop policy if exists "Users can insert own body_measurements" on body_measurements; drop policy if exists "Users can update own body_measurements" on body_measurements; drop policy if exists "Users can delete own body_measurements" on body_measurements; drop policy if exists "Trainers can read assigned member body_measurements" on body_measurements;
create policy "Users can read own body_measurements" on body_measurements for select using (auth.uid() = member_id);
create policy "Users can insert own body_measurements" on body_measurements for insert with check (auth.uid() = member_id);
create policy "Users can update own body_measurements" on body_measurements for update using (auth.uid() = member_id);
create policy "Users can delete own body_measurements" on body_measurements for delete using (auth.uid() = member_id);
create policy "Trainers can read assigned member body_measurements" on body_measurements for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = body_measurements.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Goals
drop policy if exists "Users can read own goals" on goals; drop policy if exists "Users can insert own goals" on goals; drop policy if exists "Users can update own goals" on goals; drop policy if exists "Users can delete own goals" on goals; drop policy if exists "Trainers can read assigned member goals" on goals;
create policy "Users can read own goals" on goals for select using (auth.uid() = member_id);
create policy "Users can insert own goals" on goals for insert with check (auth.uid() = member_id);
create policy "Users can update own goals" on goals for update using (auth.uid() = member_id);
create policy "Users can delete own goals" on goals for delete using (auth.uid() = member_id);
create policy "Trainers can read assigned member goals" on goals for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = goals.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Trainer feedback
drop policy if exists "Users can read own feedback" on trainer_feedback; drop policy if exists "Users can insert own feedback" on trainer_feedback; drop policy if exists "Trainers can read assigned member feedback" on trainer_feedback; drop policy if exists "Trainers can insert feedback for assigned members" on trainer_feedback;
create policy "Users can read own feedback" on trainer_feedback for select using (auth.uid() = member_id);
create policy "Users can insert own feedback" on trainer_feedback for insert with check (auth.uid() = member_id);
create policy "Trainers can read assigned member feedback" on trainer_feedback for select using (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = trainer_feedback.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);
create policy "Trainers can insert feedback for assigned members" on trainer_feedback for insert with check (
  exists (select 1 from trainer_assignments where trainer_assignments.member_id = trainer_feedback.member_id and trainer_assignments.trainer_id = auth.uid() and trainer_assignments.status = 'active')
);

-- Chat rooms
drop policy if exists "Participants can read own chat rooms" on chat_rooms; drop policy if exists "Participants can insert chat rooms" on chat_rooms;
create policy "Participants can read own chat rooms" on chat_rooms for select using (auth.uid() = participant_one or auth.uid() = participant_two);
create policy "Participants can insert chat rooms" on chat_rooms for insert with check (auth.uid() = participant_one or auth.uid() = participant_two);

-- Chat messages
drop policy if exists "Room participants can read messages" on chat_messages; drop policy if exists "Room participants can insert messages" on chat_messages;
create policy "Room participants can read messages" on chat_messages for select using (
  exists (select 1 from chat_rooms where chat_rooms.id = chat_messages.room_id and (chat_rooms.participant_one = auth.uid() or chat_rooms.participant_two = auth.uid()))
);
create policy "Room participants can insert messages" on chat_messages for insert with check (
  exists (select 1 from chat_rooms where chat_rooms.id = chat_messages.room_id and (chat_rooms.participant_one = auth.uid() or chat_rooms.participant_two = auth.uid()))
);

-- Notifications
drop policy if exists "Users can read own notifications" on notifications; drop policy if exists "Users can update own notifications" on notifications;
create policy "Users can read own notifications" on notifications for select using (auth.uid() = user_id);
create policy "Users can update own notifications" on notifications for update using (auth.uid() = user_id);
