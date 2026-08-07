alter table workout_logs
  add column if not exists total_calories integer;
