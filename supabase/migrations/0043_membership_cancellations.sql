-- Member cancellation requests with admin approval and an attendance-based refund.
do $$ begin
  create type membership_cancellation_status as enum ('pending', 'approved', 'declined');
exception when duplicate_object then null;
end $$;

create table if not exists membership_cancellation_requests (
  id uuid primary key default uuid_generate_v4(),
  member_id uuid not null references profiles(id) on delete cascade,
  membership_id uuid not null references memberships(id) on delete restrict,
  status membership_cancellation_status not null default 'pending',
  note text,
  requested_at timestamptz not null default now(),
  decided_at timestamptz,
  decided_by uuid references profiles(id),
  attendance_days integer,
  refund_amount numeric(10,2),
  membership_price numeric(10,2),
  unique (id, membership_id)
);

create unique index if not exists idx_one_pending_cancellation_per_membership
  on membership_cancellation_requests(membership_id) where status = 'pending';
create index if not exists idx_cancellation_requests_status
  on membership_cancellation_requests(status, requested_at desc);
create index if not exists idx_cancellation_requests_decided_at
  on membership_cancellation_requests(decided_at desc) where status = 'approved';
create index if not exists idx_cancellation_requests_member
  on membership_cancellation_requests(member_id, requested_at desc);

create or replace function prepare_membership_cancellation_estimate() returns trigger
language plpgsql security definer set search_path = public as $$
declare m memberships%rowtype; duration_days integer;
begin
  select * into m from memberships where id = new.membership_id and member_id = new.member_id and status = 'active';
  if not found then raise exception 'An active membership is required for cancellation'; end if;
  duration_days := greatest(1, m.end_date - m.start_date);
  select count(distinct check_in_date)::integer into new.attendance_days from attendance
    where member_id = m.member_id and check_in_date between m.start_date and m.end_date;
  new.membership_price := m.price;
  new.refund_amount := round(greatest(0, m.price - (m.price / duration_days * least(new.attendance_days, duration_days))), 2);
  return new;
end;
$$;
drop trigger if exists trg_prepare_membership_cancellation_estimate on membership_cancellation_requests;
create trigger trg_prepare_membership_cancellation_estimate before insert on membership_cancellation_requests
  for each row execute function prepare_membership_cancellation_estimate();

alter table membership_cancellation_requests enable row level security;
drop policy if exists "Members can read own cancellation requests" on membership_cancellation_requests;
create policy "Members can read own cancellation requests"
  on membership_cancellation_requests for select using (auth.uid() = member_id);
drop policy if exists "Members can create own cancellation requests" on membership_cancellation_requests;
create policy "Members can create own cancellation requests"
  on membership_cancellation_requests for insert
  with check (
    auth.uid() = member_id and status = 'pending' and
    exists (select 1 from memberships m where m.id = membership_id and m.member_id = auth.uid() and m.status = 'active')
  );
drop policy if exists "Admins all access cancellation requests" on membership_cancellation_requests;
create policy "Admins all access cancellation requests"
  on membership_cancellation_requests for all using (public.is_admin()) with check (public.is_admin());

create or replace function notify_membership_cancellation_request() returns trigger
language plpgsql security definer set search_path = public as $$
declare admin_id uuid; member_name text;
begin
  select full_name into member_name from profiles where id = new.member_id;
  for admin_id in select id from profiles where role = 'admin' loop
    insert into notifications(user_id, title, body, read)
    values(admin_id, 'Membership Cancellation Request', coalesce(member_name, 'A member') || ' requested to cancel a membership.', false);
  end loop;
  return new;
end;
$$;
drop trigger if exists trg_notify_membership_cancellation_request on membership_cancellation_requests;
create trigger trg_notify_membership_cancellation_request after insert on membership_cancellation_requests
  for each row execute function notify_membership_cancellation_request();

-- Recalculate and commit both records in one transaction so the member's plan
-- cannot be cancelled without its refund record, or vice versa.
create or replace function decide_membership_cancellation(p_request_id uuid, p_approve boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare r membership_cancellation_requests%rowtype; m memberships%rowtype;
  day_count integer; attended integer; refund numeric(10,2);
begin
  if not public.is_admin() then raise exception 'Only admins can decide cancellation requests'; end if;
  select * into r from membership_cancellation_requests where id = p_request_id for update;
  if not found then raise exception 'Cancellation request not found'; end if;
  if r.status <> 'pending' then raise exception 'This cancellation request has already been decided'; end if;
  if not p_approve then
    update membership_cancellation_requests set status = 'declined', decided_at = now(), decided_by = auth.uid()
      where id = r.id;
    return jsonb_build_object('status', 'declined');
  end if;
  select * into m from memberships where id = r.membership_id for update;
  if not found or m.member_id <> r.member_id or m.status <> 'active' then
    raise exception 'The linked membership is no longer active';
  end if;
  day_count := greatest(1, m.end_date - m.start_date);
  select count(distinct check_in_date)::integer into attended from attendance
    where member_id = m.member_id and check_in_date between m.start_date and m.end_date;
  refund := round(greatest(0, m.price - (m.price / day_count * least(attended, day_count))), 2);
  update memberships set status = 'cancelled', updated_at = now() where id = m.id;
  update membership_cancellation_requests set status = 'approved', decided_at = now(), decided_by = auth.uid(),
    attendance_days = attended, refund_amount = refund, membership_price = m.price
    where id = r.id;
  return jsonb_build_object('status', 'approved', 'attendance_days', attended, 'refund_amount', refund);
end;
$$;
revoke all on function decide_membership_cancellation(uuid, boolean) from public;
grant execute on function decide_membership_cancellation(uuid, boolean) to authenticated;
