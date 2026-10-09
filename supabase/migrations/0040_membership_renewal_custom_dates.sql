-- 0040_membership_renewal_custom_dates.sql
-- Let a member request a membership (renewal) with a custom start/end date.
-- The mobile renewal sheet collects optional start_date / end_date and stores
-- them here so the admin can honour the requested window when approving.
-- Idempotent: safe to re-run.

alter table membership_renewal_requests
  add column if not exists start_date date,
  add column if not exists end_date date;

comment on column membership_renewal_requests.start_date is
  'Optional member-requested membership start date (custom renewal window).';
comment on column membership_renewal_requests.end_date is
  'Optional member-requested membership end date (custom renewal window).';
