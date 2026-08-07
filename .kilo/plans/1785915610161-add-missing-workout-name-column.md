# Fix Remaining 400 + Add New Session Button

## Issue 1: Remaining 400 Bad Request

### Root Cause
The 400 persists because `workout_logs` is missing the `workout_name` column. The app selects and writes `workout_name` everywhere, but no migration ever added it to the database.

Current DB columns (after 00016): `exercise_name`, `sets`, `reps`, `weight_kg`, `duration_minutes`, `duration_seconds`, `proof_url`, `proof_type`, `notes`, `logged_at`  
Missing: `workout_name`

### Fix
Create `supabase/migrations/00017_add_workout_name.sql`:
```sql
alter table workout_logs
  add column if not exists workout_name text;
```

### Steps
1. Create the migration file.
2. Apply migration `00017` to the Supabase database (local and/or cloud — ensure the app's target DB receives it).
3. If using Supabase cloud, wait for PostgREST schema reload (~a few seconds) or trigger a reload.
4. Hot reload the Flutter app.
5. Verify the calendar page loads without 400.

### Validation
- Open browser DevTools → Network. The `GET .../workout_logs?select=...duration_seconds` request should return `200`.
- Existing rows will have `workout_name = null`, which the UI already handles with `?? 'Workout'`.

---

## Issue 2: Add "New Session" Button

### Current State
- `WorkoutSessionNotifier` already has `startNewSession()` and a full workout session flow.
- The calendar flip sheet back face (`_BackFace`) shows the day's workouts and ends with a "Back to Calendar" pill button.
- The home page shows an open gym session card if `openSession` exists.

### Open Question
Where should the "Add Session" / "Start New Session" button appear?

**Options:**
1. **Calendar flip sheet back face** — below the workout list, above "Back to Calendar". Tapping it calls `startNewSession()` and navigates to the workout session screen.
2. **Home page** — as a prominent button on the home dashboard, always visible.
3. **Both** — home page for quick access, calendar back face for day-specific context.

### Recommended Answer
Option 1 (calendar flip sheet back face) is the most contextually relevant: if a member is viewing their day's workouts, they can immediately start a new session for that day. The button should be styled like the existing `_GlassPillButton` and placed between the workout list and the "Back to Calendar" button.

### Edge Cases
- If a session is already running (`state.isRunning == true`), disable or hide the button.
- If the member has completed `sessionCount >= 3` sessions today, hide or disable the button (matches existing `startNewSession()` guard).
- If there are no workouts for the day, the button still appears so the member can start fresh.

### Validation
- Tap "Add Session" on calendar back face → navigates to workout session screen.
- If session is running, button is disabled.
- If 3 sessions completed, button is hidden/disabled.
