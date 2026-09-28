-- 0032: make the forecast plausibility clamp unbreakable at the database layer.
--
-- ml.py and its JS mirror (admin/server/index.js) already clamp every weight
-- forecast to +/-5% of the current value (MAX_WEIGHT_CHANGE_PCT = 0.05) and cap
-- trend confidence at 95% (MAX_CONFIDENCE = 0.95). But nothing in the schema
-- enforced it, so rows written by the pre-fix code could sit in predictions
-- uncorrected.
--
-- This file is standalone by design. If 0030_prediction_basis.sql has not been
-- applied yet, the first block adds its provenance columns idempotently; if it
-- has been applied, those statements do nothing. Apply 0031 separately if the
-- unused food table still exists.
--
-- The confidence cap deliberately EXCLUDES retention_risk: that metric's
-- confidence is a data-sufficiency score, max(0.3, min(1, weeks / 6)), which
-- legitimately reaches 1.0 with six or more weeks of check-in history. Capping
-- it at 0.95 would reject valid retention rows.
--
-- Provenance columns (same set as 0030_prediction_basis.sql).
alter table predictions
  add column if not exists current_value decimal(10,2),
  add column if not exists unit text,
  add column if not exists data_points integer,
  add column if not exists span_days integer,
  add column if not exists date_from date,
  add column if not exists date_to date,
  add column if not exists daily_rate decimal(10,4),
  add column if not exists change decimal(10,2),
  add column if not exists clamped boolean,
  add column if not exists method text,
  add column if not exists note text;

create index if not exists predictions_member_metric_date_idx
  on predictions (member_id, metric_name, predicted_date desc);
--
-- Weight forecasts must stay within +/-5% of the recorded current value,
-- mirroring MAX_WEIGHT_CHANGE_PCT = 0.05 (and MIN_PLAUSIBLE_VALUE = 0.5) in
-- ai-service/services/ml.py. Rows with no recorded current value pass
-- vacuously here; the cleanup deletes legacy rows, and the trigger below keeps
-- future rows populated.
-- Added NOT VALID so the file applies even while stale rows are still on disk;
-- the rows are validated afterwards (VALIDATE CONSTRAINT, see bottom of file).
alter table predictions
  drop constraint if exists predictions_weight_clamp_chk,
  add constraint predictions_weight_clamp_chk
    check (
      metric_name <> 'weight'
      or current_value is null
      or predicted_value is null
      or (
        predicted_value between greatest(current_value * 0.95, 0.5)
                            and current_value * 1.05
      )
    )
    not valid;
--
-- Forecast confidence never exceeds 95% (MAX_CONFIDENCE = 0.95), except for
-- retention_risk (see header note). Same NOT VALID treatment as above.
alter table predictions
  drop constraint if exists predictions_confidence_chk,
  add constraint predictions_confidence_chk
    check (
      metric_name = 'retention_risk'
      or confidence is null
      or (confidence between 0 and 0.95)
    )
    not valid;
--
-- The service writes fully-populated rows (predictions.py::_persist), but its
-- fallback insert path (used in production the whole time 0030 was missing)
-- omits current_value. Backfill it from the member's latest measurement so
-- the clamp above cannot be bypassed by writing a row without a current value.
create or replace function predictions_fill_current_value()
returns trigger as $$
begin
  if new.metric_name = 'weight' and new.current_value is null then
    select weight_kg into new.current_value
    from body_measurements
    where member_id = new.member_id
      and weight_kg is not null
    order by measured_at desc
    limit 1;
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists predictions_fill_current_value_trg on predictions;
create trigger predictions_fill_current_value_trg
  before insert or update on predictions
  for each row execute function predictions_fill_current_value();
--
-- After the Phase-3 cleanup (all legacy rows deleted and regenerated), run
-- these two lines once to prove the table is fully clean:
--   alter table predictions validate constraint predictions_weight_clamp_chk;
--   alter table predictions validate constraint predictions_confidence_chk;
-- Both must succeed with no error. If either fails, a violating row survived
-- the cleanup and needs to be investigated before sign-off.
