# New Session → Add Exercise Flow

## Goal
Change the workout page so that:
1. The "Add Exercise" form only appears after the member taps "New Session".
2. On initial load (before any session), a "New Session" button is shown instead of the add form.
3. After a session completes, the existing "New Session" button in the completed summary also reveals the add form.
4. The add form appears **above the clock card** (at the top of the scrollable content).
5. The "New Session" button shows text only — remove the `Icons.add` (`+`) icon.

## Current Behavior
- **Initial load**: Add form is visible immediately below the clock card.
- **After session completes**: Completed summary shows with a `TextButton.icon` (`+` icon + "New Session" label). Tapping it calls `startNewSession()`, which resets state but leaves `completedAt` intact, so the completed summary remains visible alongside the add form.
- **Add form position**: Below the clock card, inside the `else` branch of `if (ended)`.

## Root Cause / Gap
- `startNewSession()` preserves `completedAt`, so `completedToday` stays `true` and the summary card never disappears.
- No flag exists to track "exercise-adding mode", so the add form is always visible when `!isRunning && !sessionEnded` (including initial load).
- The "New Session" button uses `TextButton.icon` with `Icons.add`.

## Implementation

### 1. `workout_session_provider.dart` — Clear `completedAt` in `startNewSession()`

In `startNewSession()` (around line 548), change:
```dart
completedAt: state.completedAt,
```
to:
```dart
completedAt: null,
```

This ensures the completed summary disappears immediately when the user taps "New Session".

### 2. `workout_page.dart` — Add `_showAddForm` flag and restructure `build()`

**Add state field** (near `_query` and `_expandedSessions`):
```dart
bool _showAddForm = false;
```

**Add `_buildInitialNewSessionButton()`** (new method, e.g. after `_buildAddForm`):
```dart
Widget _buildInitialNewSessionButton(WorkoutSessionNotifier notifier) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFC56BF0).withAlpha(60),
          blurRadius: 14,
          offset: const Offset(0, 4),
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
        'New Session',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
```

**Update `build()` widget order** (replace lines ~149–170):
```dart
ListView(
  padding: const EdgeInsets.symmetric(horizontal: 14),
  physics: const ClampingScrollPhysics(),
  children: [
    const SizedBox(height: 14),
    _buildHeader(session),
    const SizedBox(height: 8),
    if (_showAddForm) _buildAddForm(notifier),
    _buildClockCard(session, notifier),
    const SizedBox(height: 8),
    if (session.completedToday && !_showAddForm)
      _buildCompletedSummary(session, notifier),
    if (ended)
      const SizedBox(height: 8)
    else ...[
      _buildExerciseList(session, notifier),
    ],
    if (!_showAddForm && !session.completedToday && !isRunning && !ended)
      _buildInitialNewSessionButton(notifier),
    _buildWorkoutHistory(),
    const SizedBox(height: 96),
  ],
)
```

Key changes:
- `_buildAddForm` is now gated by `_showAddForm` and placed **above** `_buildClockCard`.
- The inline `if (!isRunning) ...[_buildAddForm, SizedBox]` block is **removed** from the `else` branch.
- `_buildInitialNewSessionButton` is shown only when `_showAddForm` is false, no session is completed, and the session is idle.
- The existing `SizedBox(height: 8)` after the clock card remains.

**Update the "New Session" button inside `_buildCompletedSummary`** (around line 862–890):
- Change `TextButton.icon` → `TextButton`.
- Remove the `icon: const Icon(Icons.add, size: 18)` line.
- Add `setState(() => _showAddForm = true)` in `onPressed` alongside `notifier.startNewSession()`.

```dart
if (canStartNew) ...[
  const SizedBox(height: 14),
  Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
      borderRadius: BorderRadius.circular(14),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFC56BF0).withAlpha(60),
          blurRadius: 14,
          offset: const Offset(0, 4),
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
  ),
],
```

## State Flow After Changes

| Scenario | `_showAddForm` | `completedToday` | `ended` | Visible widgets (top→bottom) |
|---|---|---|---|---|
| Initial load | false | false | false | Header → Clock → Initial "New Session" btn → History |
| Tap "New Session" (initial) | true | false | false | Header → **Add form** → Clock → Exercise list → History |
| Session running | true | false | false | Header → **Add form** → Clock → Exercise list → History |
| Session completes | true | false | true | Header → **Add form** → Clock → Exercise list → History |
| Tap "New Session" (post-session) | true | false* | false | Header → **Add form** → Clock → Exercise list → History |

*`completedAt` is cleared by `startNewSession()`, so `completedToday` becomes `false`.

## Edge Cases
- **Session count limit**: `startNewSession()` already guards `if (state.sessionCount >= 3) return;`. Both buttons call the same method, so the limit is enforced consistently.
- **Navigating away and back**: `_showAddForm` resets to `false` on page rebuild. The user sees the current provider state (clock + history). They can tap "New Session" again if needed.
- **Rapid taps**: `startNewSession()` is idempotent (guards by `sessionCount`). `_showAddForm = true` is a local `setState`, safe to call multiple times.

## Validation
1. `flutter analyze` in `mobile/fitness_app` and `mobile/shared`.
2. **Initial load**: Verify add form is hidden; "New Session" button is visible below the clock card.
3. **Tap "New Session" (initial)**: Verify add form appears above the clock card; "New Session" button disappears.
4. **Start and complete a session**: Verify completed summary appears with text-only "New Session" button (no `+` icon).
5. **Tap "New Session" (post-session)**: Verify completed summary disappears; add form appears above the clock card.
6. **Verify** exercise list, timer, and workout history remain functional in all states.
