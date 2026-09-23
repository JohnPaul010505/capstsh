-- 0028: in-app notifications for QR attendance (Figure: gym In & Out).
--
-- Problem: the notifications insert policy ("Assigned pair can insert
-- notifications", 0023/0026) requires user_id <> auth.uid(), so the person
-- checking in can never notify *themselves* from the app. A SECURITY DEFINER
-- trigger writes the row instead — same pattern as 0027's
-- notify_membership_renewal(). Receiver = NEW.member_id, so it covers both
-- the member and the trainer QR flows with one rule.
--
-- Guards: only rows dated *today* (Asia/Manila) notify, so seeded/historical
-- backfills never spam. Notification writes must never block the attendance
-- write itself (exception handler).

create or replace function public.notify_attendance_change() returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today   date := (now() at time zone 'Asia/Manila')::date;
  v_stamp   text := to_char(now() at time zone 'Asia/Manila', 'FMHH12:MI AM');
  v_dur     text;
  v_secs    bigint;
begin
  -- ---- check-in: a fresh row opened today ----
  if (TG_OP = 'INSERT') then
    if (NEW.check_in_date is distinct from v_today) then
      return NEW;
    end if;
    begin
      insert into notifications (user_id, title, body, read)
      values (
        NEW.member_id,
        'Checked In',
        'You checked in at ' || v_stamp || '. Enjoy your workout!'
      );
    exception when others then
      null; -- never block the check-in itself
    end;
    return NEW;
  end if;

  -- ---- check-out: open session just closed by this update ----
  if (TG_OP = 'UPDATE'
      and OLD.check_out_time is null
      and NEW.check_out_time is not null) then
    v_secs := extract(epoch from (NEW.check_out_time - NEW.check_in_time))::bigint;
    if (v_secs is not null and v_secs >= 60) then
      v_dur := (v_secs / 3600)::int || ' h ' ||
               lpad(((v_secs % 3600) / 60)::text, 2, '0') || ' m';
    elsif (v_secs is not null and v_secs > 0) then
      v_dur := v_secs || ' sec';
    else
      v_dur := null;
    end if;
    begin
      insert into notifications (user_id, title, body, read)
      values (
        NEW.member_id,
        'Checked Out',
        'You checked out at ' || v_stamp ||
          case when v_dur is null then '.' else ' after ' || v_dur || '.' end
      );
    exception when others then
      null; -- never block the check-out itself
    end;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_attendance_notify on attendance;
create trigger trg_attendance_notify
  after insert or update on attendance
  for each row
  execute function public.notify_attendance_change();
