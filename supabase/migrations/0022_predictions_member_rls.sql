-- 0022: predictions (Table 25) are written by the AI service with the service
-- role (DFD 4.1). The app only needs read access:
--   - a member reads their own forecasts
--   - a trainer reads the forecasts of members assigned to them
-- No member/trainer insert or update: forecasts can only come from the service.

drop policy if exists "Members can read own predictions" on predictions;
create policy "Members can read own predictions"
  on predictions for select
  using (auth.uid() = member_id);

drop policy if exists "Trainers can read assigned member predictions" on predictions;
create policy "Trainers can read assigned member predictions"
  on predictions for select
  using (
    exists (
      select 1 from trainer_assignments
      where trainer_assignments.member_id = predictions.member_id
        and trainer_assignments.trainer_id = auth.uid()
        and trainer_assignments.status = 'active'
    )
  );
