begin;

alter table workout_logs
  add column duration_seconds int;

update workout_logs
  set duration_seconds = duration_minutes * 60
  where duration_minutes is not null;

commit;
