-- Notify the member when an admin approves or declines their renewal request,
-- and publish notifications so both mobile and admin unread badges update live.

create or replace function public.notify_membership_renewal_decision()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'pending' and new.status in ('approved', 'declined') then
    insert into public.notifications (user_id, title, body, read)
    values (
      new.member_id,
      case when new.status = 'approved'
        then 'Membership Renewal Approved'
        else 'Membership Renewal Declined'
      end,
      case when new.status = 'approved'
        then 'Your ' || new.plan_name || ' membership renewal has been approved.'
        else 'Your ' || new.plan_name || ' membership renewal request was declined. Contact the gym admin if you have questions.'
      end,
      false
    );
  end if;
  return new;
end;
$$;

drop trigger if exists trg_notify_membership_renewal_decision
  on public.membership_renewal_requests;
create trigger trg_notify_membership_renewal_decision
  after update of status on public.membership_renewal_requests
  for each row execute function public.notify_membership_renewal_decision();

do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'notifications'
  ) then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;
