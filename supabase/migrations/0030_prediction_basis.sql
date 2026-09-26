-- Prediction provenance.
--
-- A stored forecast used to be just a number, a date and a confidence, so the
-- admin table could not answer "what was this number based on?". These columns
-- record the evidence behind each forecast so any row can be traced back to the
-- measurements it was computed from.
--
-- All nullable and added without backfill: existing rows simply show as having
-- no recorded basis.

alter table predictions
  add column if not exists current_value decimal(10,2),   -- latest reading at forecast time
  add column if not exists unit text,                    -- kg | % | risk score (0-1)
  add column if not exists data_points integer,           -- measurements (or weeks) used
  add column if not exists span_days integer,             -- how far apart that history is
  add column if not exists date_from date,                -- first reading in the fit
  add column if not exists date_to date,                  -- latest reading in the fit
  add column if not exists daily_rate decimal(10,4),      -- kg/day or %-point/day trend
  add column if not exists change decimal(10,2),          -- predicted - current
  add column if not exists clamped boolean,               -- trend hit the safe-rate cap
  add column if not exists method text,                   -- ols-linear-regression | weighted-heuristic
  add column if not exists note text;                     -- plain-language explanation

create index if not exists predictions_member_metric_date_idx
  on predictions (member_id, metric_name, predicted_date desc);
