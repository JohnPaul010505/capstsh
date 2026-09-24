-- 0025: goal metadata columns required by the member Goals screen (Figure 21).
-- CreateGoalCard writes goal_type/timeframe/start_date/end_date; GoalCard renders
-- them and the shared Goal model maps them. Without these columns the insert
-- fails with 42703 and the UI shows "Something went wrong. Please try again."
alter table goals add column if not exists goal_type    text;
alter table goals add column if not exists timeframe    text;
alter table goals add column if not exists start_date   date;
alter table goals add column if not exists end_date     date;
alter table goals add column if not exists progress_pct decimal(5,2);

-- Backfill seeded rows so their cards show a real window instead of GoalCard's
-- "now -> +30 days" fallback.
update goals
   set start_date = coalesce(start_date, created_at::date),
       end_date   = coalesce(end_date, deadline),
       timeframe  = coalesce(timeframe, '1 Month')
 where start_date is null or end_date is null or timeframe is null;
