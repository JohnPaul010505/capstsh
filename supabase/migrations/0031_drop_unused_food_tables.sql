-- 0031: drop the two orphan AI food tables.
--
-- Both were introduced for the removed food features:
--   * food_recommendations     - Gemini-generated food suggestions
--   * food_identification_logs - Gemini photo-recognition candidates
--
-- Neither has a single writer left: the ai-service food routes and the
-- mobile food_recommendation_service were deleted, and the tables are not
-- referenced by any code, admin or mobile path. Keeping them in the schema
-- would contradict Chapter 1, which already describes meal logging as a
-- manual PhilFCT lookup with no AI step.
--
-- Both are empty in practice, but the drop is guarded so it cannot fail on a
-- populated table. No other table has a foreign key into either, so cascade
-- is a safety net rather than a requirement.
--
-- Before applying, confirm nothing is holding rows you need:
--   select count(*) from food_recommendations;
--   select count(*) from food_identification_logs;

do $$
declare
  rec text;
begin
  foreach rec in array array['food_recommendations', 'food_identification_logs'] loop
    if to_regclass(format('public.%I', rec)) is null then
      raise notice '0031: public.% already absent, skipping', rec;
    else
      execute format('drop table if exists public.%I cascade;', rec);
      raise notice '0031: dropped public.%', rec;
    end if;
  end loop;
end
$$;
