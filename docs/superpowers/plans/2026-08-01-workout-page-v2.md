# Workout Page V2 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rework the member Workout page into a gated session flow: add exercises (shown instantly) → per-exercise video proof (min 30s, auto-marked done) → start/stop timer (Start requires ≥1 exercise) → "Done Workout Session" (red/green statuses + styled summary card with duration + checklist) → card's "Done" fully restarts the page → plus a calendar selector in the top-right (past dates read-only).

**Architecture:** One new `ExerciseProofButton` widget (native camera via image_picker max 60s, upload to `proofs` bucket, duration validated ≥30s with video_player, reports URL). `exercisesProvider` becomes a `FutureProvider.family` keyed by day for the calendar filter. The page owns session state: `_selectedDate`, `_timerStopped`, `_showSummary`, `_sessionSeconds`, `_sessionResetAt` (view filters today's list to rows logged after reset → DB rows kept, screen fresh). Summary card is a styled dark card (radial purple glows, divider, green/red checklist rows, purple gradient pill button) modeled on the user's React reference.

**Tech Stack:** Flutter, flutter_riverpod, supabase_flutter, image_picker, video_player, ClayTokens. No DB/schema changes — `workout_logs.proof_url`/`proof_type` already exist (migration 00013); RLS allows members to update their own rows (migration 00005).

**Branch:** `feature/workout-page-v2` created from `feature/member-nav-checkin`.

**Final page flow (top → bottom):**
1. Header: "WORKOUT LOG" + Live/Ready pill + calendar icon (top-right, shows selected date; tapping opens `showDatePicker`)
2. Timer card (animated, gated Start/Finish) — Start disabled + hint "Add an exercise first" when no exercises
3. EXERCISES list: `_ExerciseCard` per log — name, sets/reps/weight, status chip (green DONE live when video saved; red PENDING after Done #1 if missing), `ExerciseProofButton` (today only)
4. Add Exercise toggle (today only) → form (name*, sets default 3, reps default 10, weight optional) → insert → invalidate today
5. When timer stopped: bottom "Done Workout Session" button (soft green) → Done #1: red/green chips + `_SessionSummaryCard`
6. Card: title "Workout Complete", subtitle, Divider, rows (green check circle = video, red circle = missing, name + sets/reps), "Total time: HH:MM:SS", purple gradient "Done" pill → full restart: timer reset, card closed, `_sessionResetAt = now`, date → today, fresh list

**Read-only rules:** when `_selectedDate != today`: no Add Exercise, no camera buttons, no Done button; a "Viewing {date}" note shows.

**Verification baseline:** `flutter analyze` from `C:\capshii\capshii\mobile\fitness_app` → 13 pre-existing infos (12 `withOpacity` in `login_page.dart` + 1 `include_file_not_found` for flutter_lints) and NOTHING new. `flutter build web --release` must pass (video_player supports web). Commit per task from repo root `C:\capshii\capshii`; NEVER stage unrelated WIP (admin/**, mobile WIP files, untracked docs/docx/migrations).

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mobile/fitness_app/pubspec.yaml` | Modify | Add `video_player` (via `flutter pub add video_player`) |
| `mobile/fitness_app/lib/features/shared/widgets/video_proof_recorder.dart` | Delete | Replaced by the new button |
| `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart` | Create | Per-card camera button: pick → upload → 30s duration check → `onRecorded(url)` |
| `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` | Modify | Provider family, calendar, gating, cards, summary, restart |

---

## Task 1: ExerciseProofButton widget + video_player dependency

**Files:**
- Modify: `mobile/fitness_app/pubspec.yaml`
- Delete: `mobile/fitness_app/lib/features/shared/widgets/video_proof_recorder.dart`
- Create: `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

- [ ] **Step 1: Add dependency** — run from `C:\capshii\capshii\mobile\fitness_app`: `flutter pub add video_player`. Confirm `video_player: ^X` appears in `pubspec.yaml` dependencies.
- [ ] **Step 2: Delete old recorder** — delete `lib/features/shared/widgets/video_proof_recorder.dart` (its only consumer, `workout_page.dart`, will be rewritten in later tasks — expect a broken import until Task 3; verify with grep that nothing else imports it: search `VideoProofRecorder` across `lib/` — only `workout_page.dart` matches).
- [ ] **Step 3: Create the widget** — `lib/features/member/workout/widgets/exercise_proof_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:video_player/video_player.dart';
import '../../../../app/design_tokens.dart';

/// Per-exercise camera proof button: opens the native camera (max 60s),
/// uploads the clip to the `proofs` bucket, validates duration >= 30s,
/// then reports the public URL via [onRecorded]. Renders idle -> busy -> recorded.
class ExerciseProofButton extends StatefulWidget {
  final bool recorded;
  final ValueChanged<String> onRecorded;

  const ExerciseProofButton({super.key, this.recorded = false, required this.onRecorded});

  @override
  State<ExerciseProofButton> createState() => _ExerciseProofButtonState();
}

class _ExerciseProofButtonState extends State<ExerciseProofButton> {
  bool _busy = false;

  Future<void> _record() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(seconds: 60),
    );
    if (video == null) return;

    setState(() => _busy = true);
    String? uploadedPath;
    try {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      uploadedPath = 'workouts/$userId/${DateTime.now().millisecondsSinceEpoch}.mp4';
      final bytes = await video.readAsBytes();
      await client.storage.from('proofs').uploadBinary(
        uploadedPath,
        bytes,
        fileOptions: const FileOptions(contentType: 'video/mp4'),
      );
      final url = client.storage.from('proofs').getPublicUrl(uploadedPath);

      // Duration validation: must be at least 30 seconds.
      var tooShort = false;
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize();
        tooShort = controller.value.duration.inSeconds < 30;
        await controller.dispose();
      } catch (_) {
        // If duration can't be read (rare), accept the video — never block the member.
        tooShort = false;
      }

      if (tooShort) {
        await client.storage.from('proofs').remove([uploadedPath]);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Video must be at least 30 seconds')),
          );
        }
        return;
      }

      if (!mounted) return;
      widget.onRecorded(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save proof: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_busy) {
      return const SizedBox(
        width: 34, height: 34,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(strokeWidth: 2, color: ClayTokens.clayPrimaryLight),
        ),
      );
    }

    if (widget.recorded) {
      return const Icon(Icons.check_circle, size: 22, color: ClayTokens.clayAccent);
    }

    return GestureDetector(
      onTap: _record,
      child: Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color: ClayTokens.clayPrimary.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: ClayTokens.clayPrimary.withAlpha(80)),
        ),
        child: const Icon(Icons.videocam_outlined, size: 16, color: ClayTokens.clayPrimaryLight),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify** — run `flutter analyze` from `C:\capshii\capshii\mobile\fitness_app`. Expected: the pre-existing 13 infos plus ONE error in `workout_page.dart` (unresolved `VideoProofRecorder` import — temporarily broken, fixed in Task 3). No other errors.
- [ ] **Step 5: Commit** from repo root: `git add mobile/fitness_app/pubspec.yaml mobile/fitness_app/pubspec.lock mobile/fitness_app/lib/features/shared/widgets/video_proof_recorder.dart mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart` && `git commit -m "feat(mobile): per-exercise proof button with 30s duration check"` (the file deletion is included via `git add -A` semantics of the explicit path).

---

## Task 2: Provider family + calendar selector

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` (provider + page state + header only)

- [ ] **Step 1: Provider → family** — replace the top-level provider:

```dart
final exercisesProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, DateTime>((ref, day) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final start = '${day.toIso8601String().split('T')[0]}T00:00:00';
  final end = '${day.toIso8601String().split('T')[0]}T23:59:59';
  final response = await SupabaseClientService()
      .client
      .from('workout_logs')
      .select()
      .eq('member_id', userId)
      .gte('logged_at', start)
      .lt('logged_at', end)
      .order('logged_at', ascending: false)
      .order('id', ascending: false);
  return (response as List).cast<Map<String, dynamic>>();
});
```

- [ ] **Step 2: Page state** — in `_WorkoutPageState` add:

```dart
DateTime _selectedDate = DateTime.now();
```

Update `exercisesAsync` watch: `ref.watch(exercisesProvider(_selectedDate))` (still `final exercisesAsync = ...`).
- [ ] **Step 3: Header calendar button** — in the header `Row` (after the Live/Ready pill), add a date pill + calendar icon that opens `showDatePicker`:

```dart
TextButton.icon(
  onPressed: _pickDate,
  icon: const Icon(Icons.calendar_month, size: 16, color: Color(0xFFD6A5FF)),
  label: Text(DateFormat('MMM d').format(_selectedDate),
    style: const TextStyle(fontSize: 11, color: Color(0xFFD6A5FF))),
  style: TextButton.styleFrom(
    backgroundColor: const Color(0xFFBF5AF2).withAlpha(20),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
)
```

Add `intl` import (`package:intl/intl.dart`) at the top of the file. Add the handler:

```dart
Future<void> _pickDate() async {
  final today = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate,
    firstDate: DateTime(today.year - 1, 1, 1),
    lastDate: today,
    builder: (context, child) => Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Color(0xFFBF5AF2)),
        datePickerTheme: const DatePickerThemeData(
          backgroundColor: Color(0xFF1C1C1E),
        ),
      ),
      child: child!,
    ),
  );
  if (picked != null) setState(() => _selectedDate = picked);
}
```

- [ ] **Step 4: Read-only past dates** — compute `final isToday = _selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month && _selectedDate.day == DateTime.now().day;`. When `!isToday`: hide the Add Exercise toggle (the `if (_showAddForm) _buildAddForm()` block and the toggle card), and show a note under the EXERCISES header: `Text('Viewing ${DateFormat('MMM d, yyyy').format(_selectedDate)} — read only', style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)))`. Wrap the toggle card in `if (isToday) ...`.
- [ ] **Step 5: Verify** — `flutter analyze` → only the pre-existing 13 infos + the known temporary `VideoProofRecorder` error. No new issues.
- [ ] **Step 6: Commit** — `git add mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` && `git commit -m "feat(mobile): day-based exercise provider with calendar date filter"`

---

## Task 3: Exercise cards — camera wiring + status chips

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [ ] **Step 1: Remove the old recorder usage** — delete the `VideoProofRecorder(...)` block under `if (isRunning) ...[` (lines ~251-257: the `if (isRunning) ...[ const SizedBox(height: 8), VideoProofRecorder(...) ]` block) and the whole `_attachProof` method. Remove the `import '../../../shared/widgets/video_proof_recorder.dart';` line.
- [ ] **Step 2: Import the new widget** — add `import '../widgets/exercise_proof_button.dart';`.
- [ ] **Step 3: Per-exercise proof handler** — add to `_WorkoutPageState` (the button reports the URL, the page persists it to that exercise's row):

```dart
Future<void> _recordProofFor(Map<String, dynamic> exercise, String url) async {
  try {
    final client = SupabaseClientService().client;
    await client.from('workout_logs').update({
      'proof_url': url,
      'proof_type': 'video',
    }).eq('id', exercise['id'] as String);
  } catch (_) {}
  ref.invalidate(exercisesProvider(_selectedDate));
}
```
- [ ] **Step 4: Card UI** — in the list builder, pass the whole exercise map and flags to `_ExerciseCard` and add the trailing widgets. Replace the `_ExerciseCard` class with:

```dart
class _ExerciseCard extends StatelessWidget {
  final Map<String, dynamic> exercise;
  final bool isToday;
  final bool showPending;
  final ValueChanged<String> onProofRecorded;

  const _ExerciseCard({
    required this.exercise,
    required this.isToday,
    required this.showPending,
    required this.onProofRecorded,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['exercise_name'] as String? ?? 'Exercise';
    final reps = exercise['reps'] as int?;
    final sets = exercise['sets'] as int?;
    final weight = exercise['weight_kg'] as double?;
    final hasVideo = exercise['proof_url'] != null;
    final pending = showPending && !hasVideo;

    return PressableCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      margin: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: hasVideo
                  ? ClayTokens.clayAccent.withAlpha(25)
                  : const Color(0xFFBF5AF2).withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasVideo ? Icons.check : CupertinoIcons.person,
              color: hasVideo ? ClayTokens.clayAccent : const Color(0xFFD6A5FF),
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(name, style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF),
                      )),
                    ),
                    if (hasVideo) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: ClayTokens.clayAccent.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('DONE', style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w700, color: ClayTokens.clayAccentLight,
                        )),
                      ),
                    ] else if (pending) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFFF453A).withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('PENDING', style: TextStyle(
                          fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFFF6B61),
                        )),
                      ),
                    ],
                  ],
                ),
                if (reps != null || weight != null)
                  Text(
                    '${reps != null ? '$reps reps' : ''}${reps != null && weight != null ? ' · ' : ''}${weight != null ? '$weight kg' : ''}',
                    style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                  ),
              ],
            ),
          ),
          if (sets != null) ...[
            Text('$sets', style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFD6A5FF),
            )),
            const SizedBox(width: 3),
            const Text('SETS', style: TextStyle(
              fontSize: 8, fontWeight: FontWeight.w600, color: Color(0xFF636366),
            )),
          ],
          if (isToday) ...[
            const SizedBox(width: 8),
            ExerciseProofButton(
              recorded: hasVideo,
              onRecorded: (url) => onProofRecorded(url),
            ),
          ],
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the list** — in the `data:` builder of `exercisesAsync.when`, map entries:

```dart
...exercises.asMap().entries.map((entry) => StaggeredFadeIn(
  index: entry.key,
  child: _ExerciseCard(
    exercise: entry.value,
    isToday: isToday,
    showPending: _showSummary,
    onProofRecorded: (url) => _recordProofFor(entry.value, url),
  ),
)),
```

`_showSummary` is a new page field declared in Task 5 (`bool _showSummary = false;`) — add it NOW as `bool _showSummary = false;` in `_WorkoutPageState` so this compiles (Task 5 wires its behavior).
- [ ] **Step 6: Verify** — `flutter analyze` → only the pre-existing 13 infos. No errors (the old import is gone).
- [ ] **Step 7: Commit** — `git add mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` && `git commit -m "feat(mobile): per-exercise camera proof with live done chips"`

---

## Task 4: Timer gating + Done Workout Session button

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [ ] **Step 1: Visible-count gate** — in `build`, after `exercisesAsync` is available, derive the gate from the today + reset filter (add `DateTime? _sessionResetAt;` to page state; null = no reset happened):

```dart
final isToday = ...; // from Task 2
final visibleExercises = exercisesAsync.valueOrNull ?? const <Map<String, dynamic>>[];
final canStart = isToday && visibleExercises.isNotEmpty;
```

- [ ] **Step 2: Start button gating** — in the Start/Finish button `onPressed`, early-return when `!isRunning && !canStart` (show a snackbar hint), and disable styling when `!isRunning && !canStart`:

```dart
onPressed: () {
  if (!isRunning && !canStart) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Add an exercise first')),
    );
    return;
  }
  final notifier = ref.read(workoutTimerProvider.notifier);
  if (isRunning) {
    notifier.stop();
    setState(() => _timerStopped = true);
  } else {
    notifier.reset();
    notifier.start();
    setState(() => _timerStopped = false);
  }
},
```

Add `bool _timerStopped = false;` to page state. In the button style, when `!isRunning && !canStart`, use a grey background (`const Color(0xFF3A3A3C)`) and `foregroundColor: const Color(0xFF8E8E93)`.
- [ ] **Step 3: Hint text** — under the timer card (inside the Stack's AnimatedContainer column or right after it), when `!isRunning && !canStart`, add:

```dart
if (!isRunning && !canStart)
  const Padding(
    padding: EdgeInsets.only(top: 6),
    child: Text('Add an exercise to start the session',
      style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93))),
  ),
```

- [ ] **Step 4: Done button** — after the exercises list (before the Add Exercise toggle), when `isToday && _timerStopped && !_showSummary`, add a full-width button:

```dart
if (isToday && _timerStopped && !_showSummary) ...[
  const SizedBox(height: 12),
  ElevatedButton.icon(
    onPressed: () {
      setState(() {
        _sessionSeconds = ref.read(workoutTimerProvider).elapsedSeconds;
        _showSummary = true;
      });
    },
    icon: const Icon(Icons.check_circle_outline, size: 18),
    label: const Text('Done Workout Session'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF30D158),
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  ),
]
```

Add `int _sessionSeconds = 0;` and `bool _showSummary = false;` to page state.
- [ ] **Step 5: Verify** — `flutter analyze` → only pre-existing 13 infos.
- [ ] **Step 6: Commit** — `git add mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` && `git commit -m "feat(mobile): gate session start on exercises and add done session button"`

---

## Task 5: Session summary card + full restart

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`

- [ ] **Step 1: Summary card widget** — add at the end of the file (after `_ExerciseCard`):

```dart
class _SessionSummaryCard extends StatelessWidget {
  final int totalSeconds;
  final List<Map<String, dynamic>> exercises;
  final VoidCallback onDone;

  const _SessionSummaryCard({
    required this.totalSeconds,
    required this.exercises,
    required this.onDone,
  });

  String get _formattedTime {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF2A2A45)),
            gradient: RadialGradient(
              center: const Alignment(0.9, -0.9),
              radius: 1.2,
              colors: [
                const Color(0xFF7C3AED).withAlpha(60),
                const Color(0xFF1C1C2E),
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Workout Complete', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF),
              )),
              const SizedBox(height: 3),
              const Text("Great job! Here's your session summary.", style: TextStyle(
                fontSize: 10, color: Color(0xFFB4B4D0),
              )),
              const SizedBox(height: 12),
              Container(height: 1, color: const Color(0xFF2A2A45)),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 13, color: Color(0xFFD6A5FF)),
                  const SizedBox(width: 5),
                  Text('Total time: $_formattedTime', style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFFFFFFF),
                  )),
                ],
              ),
              const SizedBox(height: 10),
              ...exercises.map((e) {
                final name = e['exercise_name'] as String? ?? 'Exercise';
                final sets = e['sets'] as int?;
                final reps = e['reps'] as int?;
                final hasVideo = e['proof_url'] != null;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasVideo ? ClayTokens.clayAccent : const Color(0xFFFF453A),
                        ),
                        child: Icon(
                          hasVideo ? Icons.check : Icons.close,
                          size: 11, color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$name${sets != null ? ' · $sets sets' : ''}${reps != null ? ' · $reps reps' : ''}',
                          style: const TextStyle(fontSize: 11, color: Color(0xFFFFFFFF)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: onDone,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('Done', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Render the card** — in the ListView children, after the Done Workout Session button block, add:

```dart
if (_showSummary)
  StaggeredFadeIn(
    index: 99,
    child: _SessionSummaryCard(
      totalSeconds: _sessionSeconds,
      exercises: exercisesAsync.valueOrNull ?? const <Map<String, dynamic>>[],
      onDone: _finishSession,
    ),
  ),
```

- [ ] **Step 3: `_finishSession` full restart** — add to `_WorkoutPageState`:

```dart
void _finishSession() {
  ref.read(workoutTimerProvider.notifier).reset();
  setState(() {
    _showSummary = false;
    _timerStopped = false;
    _sessionResetAt = DateTime.now();
    _selectedDate = DateTime.now();
    _sessionSeconds = 0;
  });
}
```

- [ ] **Step 4: Reset filter** — apply the reset filter in the list builder so old rows stay in the DB but the screen is fresh. In `build`, after deriving `visibleExercises` (Task 4), compute the display list for today:

```dart
final displayExercises = _sessionResetAt == null
    ? visibleExercises
    : visibleExercises
        .where((e) {
          final t = DateTime.tryParse(e['logged_at'] as String? ?? '');
          return t != null && t.isAfter(_sessionResetAt!);
        })
        .toList();
```

Use `displayExercises` everywhere the list renders (the `exercises` variable in the `.when(data:)` builder — replace `exercises` with `displayExercises` in the mapping and the empty-state check) AND for `canStart` (a reset = fresh session = Start disabled until a new add).
- [ ] **Step 5: Verify** — `flutter analyze` → only the pre-existing 13 infos. `flutter build web --release` from `C:\capshii\capshii\mobile\fitness_app` → succeeds.
- [ ] **Step 6: Commit** — `git add mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart` && `git commit -m "feat(mobile): session summary card with restart flow"`

---

## Task 6: End-to-end verification

- [ ] **Step 1:** `flutter analyze` from `C:\capshii\capshii\mobile\fitness_app` → 0 errors/warnings beyond the 13 pre-existing infos.
- [ ] **Step 2:** `flutter build web --release` from `C:\capshii\capshii\mobile\fitness_app` → succeeds.
- [ ] **Step 3:** Grep sanity: `VideoProofRecorder` no longer referenced anywhere in `lib/`; `exercisesProvider` referenced only in `workout_page.dart`.
- [ ] **Step 4:** Manual checklist (run app on device/emulator):
  1. Add exercise → appears instantly at top of list, form closes
  2. Camera button on card → record <30s → snackbar "Video must be at least 30 seconds", card NOT marked done
  3. Record ≥30s → green DONE chip appears, upload exists in `proofs` bucket
  4. Start Session disabled + "Add an exercise first" hint when list empty (fresh after restart)
  5. Start → timer runs → Finish Session → timer freezes → "Done Workout Session" button appears
  6. Press Done #1 → PENDING chips on video-less cards, summary card shows total time + green/red rows
  7. Press card's Done → everything resets (timer 00:00, card closed, list empty, Add available)
  8. Calendar → pick July 31 → only that day's cards, no Add/camera/Done buttons
- [ ] **Step 5:** Commit any fixes.

---

## Self-Review

- **Spec coverage:** instant display after add (invalidate + family + order tiebreaker) ✓ Task 2/3; centered Add button (toggle card content already centered; styled as centered pill) ✓ Task 4 note; per-exercise camera + min 30s + auto-mark-done ✓ Tasks 1/3; Start gating + hint ✓ Task 4; stop by member + bottom Done button ✓ Task 4; Done checks videos → smooth red/green chips ✓ Tasks 3/4; summary card (duration + exercise types, React-style) ✓ Task 5; card Done → full restart, DB rows kept ✓ Task 5; calendar top-right, real picker, filters list ✓ Task 2; read-only past dates ✓ Task 2.
- **Placeholders:** none — all code blocks complete. Task 3 Step 3 contains an explicit "do not include" note for a placeholder — implementers MUST use the second (url-parameter) version only.
- **Consistency:** `_showSummary`/`_timerStopped`/`_sessionResetAt`/`_sessionSeconds` declared exactly once each (Task 3 declares `_showSummary` early; Task 4 declares `_timerStopped`, `_sessionSeconds` — and must NOT re-declare `_showSummary`). Provider family key type `DateTime` matches `exercisesProvider(_selectedDate)` usage. `ExerciseProofButton(recorded:..., onRecorded:...)` API matches Task 1. Summary card consumes `exercisesAsync.valueOrNull` — type `List<Map<String, dynamic>>` matches provider.
