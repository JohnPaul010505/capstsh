# Workout History in Workout Screen + Calendar Duration/kcal Display

## Context
- User already has 3-session workout flow with `workout_name` column on `workout_logs`
- Calendar flip sheet groups by `workout_name` but doesn't show per-session totals or per-exercise duration/kcal
- User wants past sessions visible in the workout screen, populated from DB
- Current `WorkoutLog` only stores `duration_minutes` (integer); need seconds for HH:MM:SS

## Decision: Duration Storage
**Use Option A** — Add `duration_seconds` (integer) column to `workout_logs` via Supabase DB migration.
- Existing rows: NULL (UI falls back to `durationMinutes * 60`, showing `:00` seconds)
- New rows: populated from session provider
- Aligns with existing manual migration pattern (`workout_name`)

## Changes Required

### 1. DB Migration (manual, outside code)
- Add `duration_seconds` column (integer, nullable) to `workout_logs` in Supabase

### 2. `shared/lib/models/workout_log.dart`
- Add `final int? durationSeconds;`
- Add to constructor, `fromJson` (key: `duration_seconds`), `toJson`

### 3. `fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
- In `persistSession()`: set `durationSeconds` on each `WorkoutLog` using `state.elapsedSeconds` (session-level) — same value for all exercises in that session, representing when they were marked done
- Actually: use the per-exercise `sessionElapsedSeconds` we already set in `markDone()`

### 4. `fitness_app/lib/features/member/calendar/providers/month_entries_provider.dart`
- Add `duration_seconds` to the `select()` query

### 5. `fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
- In `_BackFace` grouped list:
  - Each `_SessionHeader` shows: session name + total duration + total kcal
  - Each exercise card shows: exercise name, duration (HH:MM:SS from `duration_seconds`), kcal
  - kcal per exercise computed at render time using MET lookup + `weight_kg` + duration

### 6. New provider: `fitness_app/lib/features/member/workout/providers/workout_history_provider.dart`
- `workoutHistoryProvider`: `FutureProvider.autoDispose.family<Map<String, List<WorkoutLog>>, DateTime>`
- Fetches today's `workout_logs` for the member, grouped by `workout_name`
- Falls back to `'Workout'` for null `workout_name`

### 7. `fitness_app/lib/features/member/workout/pages/workout_page.dart`
- Import new provider
- Add `_buildWorkoutHistory()` section below the active session area
- Shows each past session as an expandable card with:
  - Session name (e.g., "Workout S1")
  - Session total duration + total kcal
  - Expandable exercise list with per-exercise duration (HH:MM:SS) and kcal
- Tapping a session toggles expansion
- History section hidden when there are no past sessions for today

## kcal Computation
Since `WorkoutLog` doesn't store kcal, compute at render time:
```dart
double _kcalFor(String exerciseName, double weightKg, int durationSeconds) {
  final met = getMetValue(exerciseName);
  final hours = durationSeconds / 3600.0;
  return met * weightKg * hours;
}
```
Uses current MET catalog values — acceptable approximation.

## Edge Cases
- Legacy rows with null `workout_name` → grouped under `"Workout"`
- Legacy rows with null `duration_seconds` → display as `0:00:00` or fallback to `durationMinutes`
- `_SessionHeader` total kcal is sum of computed per-exercise kcal
- History provider is `autoDispose` so it refreshes when navigating back

## Files Modified
1. `mobile/shared/lib/models/workout_log.dart`
2. `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`
3. `mobile/fitness_app/lib/features/member/calendar/providers/month_entries_provider.dart`
4. `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
5. `mobile/fitness_app/lib/features/member/workout/providers/workout_history_provider.dart` (new)
6. `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
