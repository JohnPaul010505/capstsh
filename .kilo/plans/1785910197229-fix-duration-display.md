# Fix 00:00:00 Duration Display + Calendar Session Grouping

## Root Cause
The `duration_seconds` DB migration likely added the column with `DEFAULT 0`. Existing rows therefore have `duration_seconds = 0`. The current duration-resolution logic only falls back to `duration_minutes * 60` when `duration_seconds` is **null** — it does **not** fall back when `duration_seconds` is `0`. Result: every existing row returns `0` seconds → `00:00:00`.

This affects both:
- `calendar_flip_sheet.dart` `_durationSeconds()`
- `workout_page.dart` workout-history section

## Required Changes

### 1. `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`
Replace `_durationSeconds` with a helper that treats `0` as missing:

```dart
int _durationSeconds(Map<String, dynamic> w) {
  final sec = w['duration_seconds'] as int?;
  final min = w['duration_minutes'] as int? ?? 0;
  if (sec != null && sec > 0) return sec;
  return min * 60;
}
```

### 2. `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`
In `_buildWorkoutHistory()`, replace the inline duration resolution (lines 515-517 and 614) with the same rule:

```dart
int _resolveDuration(int? seconds, int? minutes) {
  if (seconds != null && seconds > 0) return seconds;
  return (minutes ?? 0) * 60;
}
```

Use `_resolveDuration(e.durationSeconds, e.durationMinutes)` for both `totalDuration` and per-exercise `dur`.

### 3. Verify DB migration
If the user hasn't run the `duration_seconds` migration yet, or ran it with `DEFAULT 0`, existing rows will permanently show `0` until backfilled. The display fix above ensures `duration_minutes` is used as fallback. If `duration_minutes` is also `0` (due to original `.inMinutes` truncation on sub-minute exercises), there is no recoverable data for those rows.

## Calendar Format
The calendar flip sheet already groups by `workout_name` and renders:
```
[_SessionHeader: Workout S1 | 00:00:00 | 0 kcal]
  [_WorkoutCard: Cable Fly ...]
  [_WorkoutCard: Pull-up ...]
  [_WorkoutCard: Push-up ...]
```
This matches the requested format. Once duration/kcal values are non-zero, the headers will show real totals.

## Validation
1. Run `flutter analyze` in `mobile/fitness_app`
2. Run `flutter analyze` in `mobile/shared`
3. Verify calendar flip sheet shows non-zero duration/kcal for existing workouts
4. Verify workout page history section shows non-zero duration/kcal
