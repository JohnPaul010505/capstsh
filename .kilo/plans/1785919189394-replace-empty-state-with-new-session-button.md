# Plan: Replace empty-state text with New Session button

## Problem
- `_buildExerciseList` shows a passive "No exercises yet — search above to add one" message when the exercise list is empty.
- The actual "New Session" button is rendered below that text, so users either miss it or think they must add exercises first.
- After completing a session, the bottom button can also be hidden if `_showAddForm` was left `true` (partially addressed already, but the empty-state text still blocks the UX).

## Goal
When the workout screen has no exercises and no active/ended session, the empty space should show a clear **"New Session"** call-to-action instead of placeholder text.

## Changes

### `lib\features\member\workout\pages\workout_page.dart`

1. **Replace empty state in `_buildExerciseList`**  
   Currently (lines 486–497):
   ```dart
   if (session.exercises.isEmpty) {
     return const Padding(
       padding: EdgeInsets.symmetric(vertical: 24),
       child: Center(
         child: Text(
           'No exercises yet — search above to add one',
           style: TextStyle(color: Color(0xFF636366), fontSize: 12),
         ),
       ),
     );
   }
   ```
   Change to:
   ```dart
   if (session.exercises.isEmpty && !session.isRunning && !session.sessionEnded) {
     return _buildInitialNewSessionButton(notifier);
   }
   ```
   - If exercises are empty **and** the session is idle (not running, not ended), render the "New Session" button directly.
   - If the session has ended, fall through to `const SizedBox.shrink()` so the post-session bottom button (already in the parent) is the only action shown.

2. **Remove duplicate button from parent `build`**  
   Remove lines 174–175:
   ```dart
   if (!_showAddForm && !session.completedToday && !isRunning && !ended)
     _buildInitialNewSessionButton(notifier),
   ```
   The button is now rendered inside `_buildExerciseList` when appropriate, so the parent no longer needs to render it separately.

3. **Keep bottom button for post-session**  
   Leave lines 176–177 unchanged:
   ```dart
   if (session.sessionEnded && session.sessionCount < 3 && !_showAddForm && !isRunning)
     _buildBottomNewSessionButton(session, notifier),
   ```

## Validation
- Run `flutter analyze lib/features/member/workout/pages/workout_page.dart`
- Manually verify:
  - Fresh open (no exercises, no session ended): sees "New Session" button in the exercise-list area.
  - During a session (exercises present): sees exercise cards, no empty-state text.
  - After session ends: sees completed summary + bottom "New Session" button.
