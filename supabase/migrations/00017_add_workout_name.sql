alter table workout_logs
  add column if not exists workout_name text;
