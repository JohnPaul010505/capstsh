-- Enable Realtime for all tables the app subscribes to via .stream()
-- (idempotent). These tables exist and RLS is enabled, but none were ever
-- added to the supabase_realtime publication, so subscriptions failed with
-- "Unable to subscribe to changes ... Please check Realtime is enabled".
--
--   chat_messages   -> chat_page.dart, chat_room_page.dart
--   attendance      -> home_page.dart (check-in stream)
--   workout_logs    -> home_page.dart, member_progress_page.dart
--   meal_logs       -> member_progress_page.dart
do $$
declare
  t text;
begin
  foreach t in array array[
    'chat_messages',
    'attendance',
    'workout_logs',
    'meal_logs'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
