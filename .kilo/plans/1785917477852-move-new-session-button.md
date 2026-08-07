# Move Post-Session "New Session" Button to Bottom

## Context
- A previous change added an "Add Session" button to the calendar flip sheet back face (`_BackFace`). This needs to be removed.
- On the workout screen, after completing a session, `_buildCompletedSummary` shows a "New Session" button inside the summary card. The user wants this button moved to the bottom of the screen instead.

## Changes

### 1. Remove calendar "Add Session" button
**File:** `mobile/fitness_app/lib/features/member/calendar/widgets/calendar_flip_sheet.dart`

Remove the block added in `_BackFace.build()` between the workout list and "Back to Calendar":
```dart
if (!sessionState.isRunning && sessionState.sessionCount < 3)
  Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 4),
    child: SizedBox(
      width: double.infinity,
      child: _GlassPillButton(
        label: 'Add Session',
        onPressed: () => context.go('/member/workout'),
      ),
    ),
  ),
```
Also remove the now-unused `import 'package:go_router/go_router.dart';` and `import '../../workout/providers/workout_session_provider.dart';` if no longer needed. Revert `_BackFace` back to `StatelessWidget` with `build(BuildContext context)`.

### 2. Move "New Session" button to bottom of workout screen
**File:** `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

#### a. Remove button from summary card
In `_buildCompletedSummary`, delete the `if (canStartNew)` block (lines ~895–925) that renders the purple "New Session" button inside the summary card.

#### b. Add bottom button
Add a new method:
```dart
Widget _buildBottomNewSessionButton(WorkoutSessionNotifier notifier) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0xFFC56BF0).withAlpha(60),
          blurRadius: 14,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: TextButton(
      onPressed: () {
        notifier.startNewSession();
        setState(() => _showAddForm = true);
      },
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
      child: Text(
        'New Session ${session.sessionCount < 2 ? '' : '(${session.sessionCount}/3)'}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
```

#### c. Insert button at bottom
In the `ListView` children, after `_buildWorkoutHistory()`, add:
```dart
if (session.sessionCount > 0 && session.sessionCount < 3 && !_showAddForm && !isRunning)
  _buildBottomNewSessionButton(notifier),
```

Keep the existing `_buildInitialNewSessionButton` for the pre-first-session state.

## Validation
- Run `flutter analyze` in `mobile/fitness_app`
- Verify: before any session, the initial "New Session" button appears in the middle of the screen
- Verify: after completing a session, the summary card no longer has a "New Session" button
- Verify: after completing a session, a "New Session" button appears at the bottom
- Verify: tapping the bottom button opens the exercise search form and increments session count
- Verify: button hides when `_showAddForm` is true or session is running
- Verify: button hides when `sessionCount >= 3`
