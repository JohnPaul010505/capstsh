-- 0024: food_recommendations (Data Dictionary Table 18 / ERD) is written by the
-- member app after fetching AI suggestions. The table previously had ONLY an
-- admin policy (00001:256 / 00006:55), so member inserts were silently denied.

drop policy if exists "Members can read own food recommendations" on food_recommendations;
create policy "Members can read own food recommendations"
  on food_recommendations for select
  using (auth.uid() = member_id);

drop policy if exists "Members can insert own food recommendations" on food_recommendations;
create policy "Members can insert own food recommendations"
  on food_recommendations for insert
  with check (auth.uid() = member_id);

drop policy if exists "Trainers can read assigned member recommendations" on food_recommendations;
create policy "Trainers can read assigned member recommendations"
  on food_recommendations for select
  using (
    exists (
      select 1 from trainer_assignments ta
      where ta.member_id = food_recommendations.member_id
        and ta.trainer_id = auth.uid()
        and ta.status = 'active'
    )
  );
