-- Public enrollment creates a locked Auth account. Admin approval unlocks it,
-- while the linked profile keeps the applicant's chosen credentials intact.
alter table public.enrollments
  add column if not exists auth_user_id uuid references auth.users(id) on delete set null;

create or replace function public.notify_admin_new_enrollment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.notifications (user_id, title, body, read)
  select p.id,
         'New enrollment application',
         'A membership application from ' || coalesce(new.full_name, 'a new applicant') || ' is ready for review.',
         false
  from public.profiles p
  where p.role = 'admin';
  return new;
end;
$$;

drop trigger if exists trg_notify_admin_new_enrollment on public.enrollments;
create trigger trg_notify_admin_new_enrollment
  after insert on public.enrollments
  for each row
  when (new.status = 'pending')
  execute function public.notify_admin_new_enrollment();

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'enrollments'
  ) then
    alter publication supabase_realtime add table public.enrollments;
  end if;
end $$;
