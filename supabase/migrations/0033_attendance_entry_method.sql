-- 0033: record how each attendance row was created so the dashboard's
-- Check-in Records table can show a real Entry Method column.
--
-- The DEFAULT 'qr' backfills all pre-existing rows (every mobile QR / button
-- check-in since the service is the only writer that has existed) as QR.
-- The admin manual check-in path writes 'manual' explicitly.
--
-- Apply in the Supabase SQL editor (one paste). The admin app degrades
-- gracefully before 0033 is applied: its attendance query retries without
-- this column and renders '—' in the Entry Method column instead of failing.
alter table attendance add column if not exists entry_method text not null default 'qr';
do $$ begin
  alter table attendance add constraint attendance_entry_method_chk
    check (entry_method in ('qr', 'manual'));
exception when duplicate_object then null; end $$;
