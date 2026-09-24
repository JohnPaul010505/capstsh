-- 0027_membership_renewals.sql
-- Membership renewal requests: member applies from the mobile app,
-- admins are notified, and the admin Memberships page can Accept/Decline.
-- Idempotent: safe to re-run.

-- ---- 1. status enum ----
do $$
begin
  create type membership_renewal_status as enum ('pending', 'approved', 'declined');
exception
  when duplicate_object then null;
end $$;

-- ---- 2. table ----
create table if not exists membership_renewal_requests (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  membership_id uuid references memberships(id) on delete set null,
  plan_name text not null,
  months int not null default 1,
  status membership_renewal_status not null default 'pending',
  note text,
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references profiles(id)
);

create index if not exists idx_renewal_requests_member
  on membership_renewal_requests(member_id);
create index if not exists idx_renewal_requests_status
  on membership_renewal_requests(status);

alter table membership_renewal_requests enable row level security;

-- ---- 3. RLS ----
drop policy if exists "Members can read own renewal requests" on membership_renewal_requests;
create policy "Members can read own renewal requests"
  on membership_renewal_requests for select
  using (auth.uid() = member_id);

drop policy if exists "Members can create own renewal requests" on membership_renewal_requests;
create policy "Members can create own renewal requests"
  on membership_renewal_requests for insert
  with check (auth.uid() = member_id and status = 'pending');

drop policy if exists "Admins all access" on membership_renewal_requests;
create policy "Admins all access"
  on membership_renewal_requests for all
  using (public.is_admin())
  with check (public.is_admin());

-- ---- 4. notify every admin when a member applies ----
-- SECURITY DEFINER is required: the insert policy on notifications only allows
-- the assigned trainer/member pair as receiver, and here the receiver is an admin.
create or replace function notify_membership_renewal() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  admin_id uuid;
  member_name text;
begin
  select full_name into member_name from profiles where id = new.member_id;

  for admin_id in select id from profiles where role = 'admin' loop
    insert into notifications (user_id, title, body, read)
    values (
      admin_id,
      'Membership Renewal Request',
      coalesce(member_name, 'A member') || ' requested a ' || new.plan_name ||
        ' membership renewal' ||
        (case when new.months > 1 then ' (' || new.months || ' months)' else '' end) || '.',
      false
    );
  end loop;

  return new;
end;
$$;

drop trigger if exists trg_notify_membership_renewal on membership_renewal_requests;
create trigger trg_notify_membership_renewal
  after insert on membership_renewal_requests
  for each row execute function notify_membership_renewal();
