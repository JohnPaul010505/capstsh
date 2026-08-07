# Fix Calendar 400 Bad Request: Add `duration_seconds` to `workout_logs`

## Problem
The calendar page hits a Supabase 400 because `month_entries_provider.dart` selects `duration_seconds`, but the `workout_logs` table only has `duration_minutes`. The Flutter model/UI were partially migrated to `duration_seconds` without a matching database migration.

## Root Cause Analysis
- **DB schema** (`00001_initial_schema.sql`): `workout_logs` has `duration_minutes int`
- **App writes**: `workout_log.dart` `toJson()` emits `duration_seconds`
- **App reads**: `month_entries_provider.dart` selects `duration_seconds`; `calendar_flip_sheet.dart` reads `duration_seconds`
- **App deserialization**: `workout_log.dart` `fromJson()` still reads `json['duration_minutes']` — will return `null` after migration unless fixed

## Decision
Add `duration_seconds` to the database and backfill from `duration_minutes`. This matches the intended app behavior (`duration_seconds` only). Do **not** rename the existing column; add a new one and backfill to avoid data loss.

## Steps

### 1. Database migration
Create `supabase/migrations/00016_add_duration_seconds.sql`:
```sql
begin;

alter table workout_logs
  add column duration_seconds int;

update workout_logs
  set duration_seconds = duration_minutes * 60
  where duration_minutes is not null;

commit;
```

### 2. Fix model deserialization
In `shared/lib/models/workout_log.dart`, update `fromJson()`:
- Change `durationMinutes: json['duration_minutes'] as int?,` to `durationSeconds: json['duration_seconds'] as int?,`
- The `durationMinutes` field on the model can remain temporarily if other code still references it, but the active read path must use `duration_seconds`.

### 3. Verify app code alignment
Confirm these already match the new schema:
- `month_entries_provider.dart` — selects `duration_seconds`
- `calendar_flip_sheet.dart` — reads `duration_seconds` only
- `workout_log.dart` `toJson()` — writes `duration_seconds`

### 4. Run migration
Apply migration `00016` to the Supabase project.

### 5. Validate
- Run `flutter analyze` — must pass
- Load the calendar page — must not show 400 Bad Request
- Verify existing rows now have `duration_seconds` populated

## Risk
- Existing rows where `duration_minutes` was `null` will get `duration_seconds = null`.
- New inserts must continue to write `duration_seconds` from the app side (`toJson()` already does this).
- If any other feature still reads `duration_minutes` from the DB, it will break. Search confirmed no other Dart files reference `duration_minutes` actively.
