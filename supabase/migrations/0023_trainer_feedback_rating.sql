-- 0023: trainer feedback rating (Figure 20 - the Member rates the trainer 1-5)
-- + notifications insert policy (Figure 20 - "the system sends a notification to
--   the Member"). The three mobile createNotification() calls are silently
--   denied today because notifications only had select/update-own policies.

-- ---- 1. rating columns on trainer_feedback (Data Dictionary Table 15) ----
alter table trainer_feedback add column if not exists rating int;
alter table trainer_feedback add column if not exists rated_at timestamptz;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'trainer_feedback_rating_check'
      and conrelid = 'trainer_feedback'::regclass
  ) then
    alter table trainer_feedback
      add constraint trainer_feedback_rating_check
      check (rating is null or rating between 1 and 5);
  end if;
end $$;

-- ---- 2. the member may attach a rating to feedback addressed to them ----
-- (Existing policies: member/trainer select + insert from 00005, admin all from 00006.)
drop policy if exists "Members can rate own feedback" on trainer_feedback;
create policy "Members can rate own feedback"
  on trainer_feedback for update
  using (auth.uid() = member_id)
  with check (auth.uid() = member_id);

-- Guard: a member may only touch rating/rated_at. Rewriting the trainer's
-- content or re-pointing trainer_id/member_id is rejected.
create or replace function guard_trainer_feedback_rating() returns trigger as $$
begin
  if auth.uid() is not null and auth.uid() = new.member_id then
    if new.content is distinct from old.content
       or new.trainer_id is distinct from old.trainer_id
       or new.member_id is distinct from old.member_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Members may only update the rating of their feedback';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_guard_trainer_feedback_rating on trainer_feedback;
create trigger trg_guard_trainer_feedback_rating
  before update on trainer_feedback
  for each row execute function guard_trainer_feedback_rating();

-- ---- 3. notifications: the assigned trainer/member pair may notify each other ----
drop policy if exists "Assigned pair can insert notifications" on notifications;
create policy "Assigned pair can insert notifications"
  on notifications for insert
  to authenticated
  with check (
    user_id <> auth.uid()
    and exists (
      select 1 from trainer_assignments ta
      where ta.status = 'active'
        and (
          (ta.trainer_id = auth.uid() and ta.member_id = user_id)
          or (ta.member_id = auth.uid() and ta.trainer_id = user_id)
        )
    )
  );
