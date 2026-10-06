-- 0038: a member's own comment on the trainer's feedback
--
-- One reply per feedback, written by the member the feedback was addressed to.
-- Two nullable columns rather than a child table because the answer to "does
-- this feedback have a member comment, and when was it written" is needed on
-- the same row the admin list already selects; a join would put a second table
-- on a query that is otherwise a single paginated read.

alter table trainer_feedback add column if not exists member_comment text;
alter table trainer_feedback add column if not exists member_commented_at timestamptz;

-- No new RLS policy is needed, and that is deliberate: the member UPDATE policy
-- added in 0023 already scopes to `auth.uid() = member_id`, which is exactly
-- the audience for a comment. The guard trigger below is what keeps that policy
-- from becoming a licence to rewrite the trainer's note.

-- The guard widened from rating-only to rating-and-comment.
--
-- It exempts a member update ONLY when `auth.uid() = new.member_id`, i.e. the
-- row is addressed to them. For that caller, content / trainer_id / member_id /
-- created_at are still frozen and the rating plus the comment pair are theirs to
-- change. Everything else in this `if` is unchanged, and callers that do not
-- match it (trainers, and admin acting through the admin policy) fall through to
-- the policy that let them in - which is unchanged from 0023.
create or replace function guard_trainer_feedback_rating() returns trigger as $$
begin
  if auth.uid() is not null and auth.uid() = new.member_id then
    if new.content is distinct from old.content
       or new.trainer_id is distinct from old.trainer_id
       or new.member_id is distinct from old.member_id
       or new.created_at is distinct from old.created_at then
      raise exception 'Members may only update the rating and comment of their feedback';
    end if;
  end if;
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_guard_trainer_feedback_rating on trainer_feedback;
create trigger trg_guard_trainer_feedback_rating
  before update on trainer_feedback
  for each row execute function guard_trainer_feedback_rating();