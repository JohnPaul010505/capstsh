-- 0049: goal_category separates workout (weight) goals from food (calorie) goals.
-- The member Goals screen switches between the two with a burger button, and a
-- food goal's target_value is a DAILY kcal target (unit 'kcal/day'), not a
-- weight in kg. Every other reader of the goals table (home forecast, the
-- Android launcher widget, and the trainer insight/progress screens) picks the
-- newest ACTIVE goal and assumes it is a weight goal, so they must scope to
-- goal_category = 'workout' or a calorie goal would corrupt their math.
-- Existing rows backfill to 'workout' so nothing changes for current members.
alter table goals add column if not exists goal_category text not null default 'workout';

-- Keep the value constrained to the two known categories.
alter table goals drop constraint if exists goals_goal_category_check;
alter table goals
  add constraint goals_goal_category_check
  check (goal_category in ('workout', 'food'));
