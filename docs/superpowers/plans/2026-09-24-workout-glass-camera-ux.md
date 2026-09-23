# Workout Glass UI + Proof Camera UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Glass-style exercise cards, readable Done button, front/back camera toggle with fullscreen recorder (nav bar hidden), recording progress line under the "Proof Video" title, non-stretching video viewer, and a purple/red/green Ready–Live–Done status chip.

**Architecture:** Pure Flutter UI changes across 5 files. No DB/schema/provider changes. The recorder becomes fullscreen by pushing on the **root navigator** (covers the shell's `bottomNavigationBar`). The viewer sizes itself to the video's true aspect ratio (portrait default before load) so nothing can ever stretch.

**Tech Stack:** Flutter, ClayTokens/`ClayCard`, `camera ^0.12.0+2`, `video_player 2.11.1`, Riverpod (unchanged).

**Spec:** User's 7 screenshot concerns (member workout page UX pass, 2026-09-24).

## Global Constraints

- Flutter only — zero migrations, zero API changes
- Only stage these 5 files (teammates have dirty files in the repo):
  - `mobile/fitness_app/lib/features/member/workout/widgets/workout_exercise_list.dart`
  - `mobile/fitness_app/lib/features/member/workout/widgets/workout_header.dart`
  - `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`
  - `mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart`
  - `mobile/fitness_app/lib/features/shared/widgets/proof_video_viewer.dart`
- Verification baseline: `flutter analyze --no-pub` from `mobile/fitness_app/` → record count BEFORE changes; no NEW issues after
- Fix latent `BoxDecoration` bug while touching files: never pass both `color:` and `gradient:` (asserts in debug)

## Review Focus

1. Proof flow regression from `rootNavigator: true` — URL must still return via `Navigator.pop`, Android back + `PopScope` during upload must still work.
2. Camera flip races — disposing while initializing, flipping mid-recording → flip gated to `ready` stage only.
3. ClayCard padding double-application — must set `padding: none` + `customPadding`.
4. Viewer aspect before init — `aspectRatio` can be 0/NaN pre-init → guarded fallback `9/16`.
5. Chip state mapping regressions — Ready before start / Live while running / Done after end, all readable.


## Task 1: Glass exercise card + readable Done button (concerns 1, 2, 6)

**File:** `mobile/fitness_app/lib/features/member/workout/widgets/workout_exercise_list.dart`

- [ ] **Step 1: Add ClayCard import** (file already imports `design_tokens.dart`):

```dart
import '../../../shared/widgets/clay/clay_card.dart';
```

- [ ] **Step 2: Replace the opaque card `Container` with the glass ClayCard** — same recipe as `WorkoutClockCard`. Replace:

```dart
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: isCurrent ? const Color(0xFF1C1C2E) : ClayTokens.clayDarkSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: isCurrent ? const Color(0xFFA78BFA).withAlpha(80) : const Color(0xFF2A2A45),
        width: isCurrent ? 1.5 : 1,
      ),
    ),
    child: Column(
```

with:

```dart
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: ClayCard(
    variant: ClayCardVariant.outlined,
    // Same glass recipe as WorkoutClockCard; brighter tint marks the current card.
    backgroundColor: isCurrent
        ? ClayTokens.clayPrimaryLight.withAlpha(45)
        : ClayTokens.clayPrimaryLight.withAlpha(25),
    borderRadius: BorderRadius.circular(16),
    padding: ClayCardPadding.none,
    customPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Column(
```

Keep the existing `Column(...)` content unchanged; closing parens already match.

## Concern → Task map

| # | Concern | Task |
|---|---|---|
| 1 | Selected-workout card → glass like Session Duration | Task 1 |
| 2 | Active card glass + unreadable button text | Task 1 (card + button) |
- [ ] **Step 3: Fix the Done button** — enabled = solid white on green; disabled = dark glass with high-contrast text. Replace the whole `Center(child: Container(...TextButton...))` block with:

```dart
Center(
  child: Container(
    decoration: hasVideo
        ? BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF16A34A)]),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF16A34A).withAlpha(60),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: Colors.white.withAlpha(12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
    child: TextButton(
      onPressed: hasVideo ? onDone : null,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white.withAlpha(190),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      ),
      child: Text(
        hasVideo ? 'Done — Timestamp Now' : 'Record proof to unlock Done',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: hasVideo ? Colors.white : Colors.white.withAlpha(210),
        ),
        textAlign: TextAlign.center,
      ),
    ),
  ),
),
```

- [ ] **Step 4: Run analyze** — `flutter analyze --no-pub` → no new issues vs baseline.
- [ ] **Step 5: Commit** — `git add mobile/fitness_app/lib/features/member/workout/widgets/workout_exercise_list.dart`

## Task 2: Glass proof strips (concerns 2 & 6 inner strips)

**File:** `mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

- [ ] **Step 1: Glass the "No video proof yet" placeholder strip** — replace its `BoxDecoration` with:

```dart
decoration: BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withAlpha(14),
      ClayTokens.clayPrimaryLight.withAlpha(22),
    ],
  ),
  borderRadius: BorderRadius.circular(12),
- [ ] **Step 2: Glass the "Video saved · tap to view" strip** — replace its `BoxDecoration` with (also removes the illegal `color` + `gradient` combo):

```dart
decoration: BoxDecoration(
  gradient: RadialGradient(
    center: const Alignment(0.9, -0.9),
    radius: 1.3,
    colors: [
      const Color(0xFF7C3AED).withAlpha(60),
      const Color(0xFF1C1C2E).withAlpha(215),
    ],
  ),
  borderRadius: BorderRadius.circular(12),
  border: Border.all(color: Colors.white.withAlpha(30)),
),
```

- [ ] **Step 3: Analyze** — `flutter analyze --no-pub` → no new issues.
- [ ] **Step 4: Commit** — `git add mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

## Task 3: Front/back camera toggle + hide nav bar (concern 3)

**Files:** `proof_camera_screen.dart`, `exercise_proof_button.dart`

- [ ] **Step 1: Add state fields** in `_ProofCameraScreenState`:

```dart
List<CameraDescription> _cams = const [];
CameraLensDirection _lens = CameraLensDirection.back;
bool _flipping = false;
```

- [ ] **Step 2: Use `_lens` in `_initCamera`**:

```dart
Future<void> _initCamera() async {
  try {
    _cams = await availableCameras();
    if (_cams.isEmpty) throw StateError('No camera found on this device');
    final camera = _cams.firstWhere(
      (c) => c.lensDirection == _lens,
      orElse: () => _cams.first,
    );
    _camera = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _camera!.initialize();
    if (!mounted) return;
    setState(() => _stage = _ProofStage.ready);
  } catch (_) {
    if (!mounted) return;
    setState(() => _stage = _ProofStage.error);
  }
}
```

- [ ] **Step 3: Add flip logic** (after `_startFromReady`):

```dart
bool get _canFlip =>
    _cams.length > 1 && !_flipping && _stage == _ProofStage.ready;

Future<void> _flipCamera() async {
  if (!_canFlip) return;
  setState(() => _flipping = true);
  _lens = _lens == CameraLensDirection.back
      ? CameraLensDirection.front
      : CameraLensDirection.back;
  final old = _camera;
  _camera = null;
  if (mounted) setState(() {});
  try {
    await old?.dispose();
  } catch (_) {}
  await _initCamera();
  if (mounted) setState(() => _flipping = false);
}
```
- [ ] **Step 4: Add the flip button to the top bar** — replace the trailing `const SizedBox(width: 40)` in `_buildTopBar()` with:

```dart
PressableCard(
  onTap: _canFlip ? _flipCamera : null,
  padding: const EdgeInsets.all(10),
  borderRadius: BorderRadius.circular(999),
  child: const Icon(Icons.cameraswitch_outlined, color: Colors.white, size: 20),
),
```

- [ ] **Step 5: Hide the member nav bar — push on the root navigator.** In `exercise_proof_button.dart`, both `_record()` and `_recordWeb()`, change `Navigator.of(context).push<String>(` to `Navigator.of(context, rootNavigator: true).push<String>(`.

- [ ] **Step 6: Analyze** — `flutter analyze --no-pub` → no new issues.
- [ ] **Step 7: Device test** — open Record Proof → no nav bar; flip front/back; record 30s on each; back button during Ready? closes cleanly; upload completes.
- [ ] **Step 8: Commit** — `git add mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart mobile/fitness_app/lib/features/member/workout/widgets/exercise_proof_button.dart`

## Task 4: Red progress line under "Proof Video" (concern 4)

**File:** `proof_camera_screen.dart`

- [ ] **Step 1: Rebuild `_buildTopBar()`** so REC + title + red line stack at the top. Replace the whole method with:

```dart
Widget _buildTopBar() {
  final recording = _stage == _ProofStage.recording;
  final seconds = ProofCameraScreen.recordDuration.inSeconds;
  final elapsed = ((_progress?.value ?? 0) * seconds).floor();
  return SafeArea(
    child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (recording)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: ClayColors.clayError,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'REC ${elapsed < 10 ? '0$elapsed' : '$elapsed'}/$seconds s',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                PressableCard(
                  onTap: _stage == _ProofStage.error
                      ? () => Navigator.of(context).pop(null)
                      : _stage == _ProofStage.uploading
                          ? null
                          : _close,
                  padding: const EdgeInsets.all(10),
                  borderRadius: BorderRadius.circular(999),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
                const Spacer(),
                const Text(
                  'Proof Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                PressableCard(
                  onTap: _canFlip ? _flipCamera : null,
                  padding: const EdgeInsets.all(10),
                  borderRadius: BorderRadius.circular(999),
                  child: const Icon(Icons.cameraswitch_outlined,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
            if (recording) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: LinearProgressIndicator(
                  value: _progress?.value ?? 0,
                  minHeight: 4,
                  backgroundColor: Colors.white24,
                  color: ClayTokens.clayError,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
```

- [ ] **Step 2: Strip REC + progress out of `_buildRecordingOverlay()`** — replace the whole method with:

```dart
Widget _buildRecordingOverlay() {
  return Column(
    children: [
      const Spacer(),
      SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: PressableCard(
            onTap: _cancelRecording,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            borderRadius: BorderRadius.circular(999),
            child: const Text(

## Task 5: Portrait / non-stretching video viewer (concern 5)

**File:** `proof_video_viewer.dart`

- [ ] **Step 1: Size the dialog to the video's real aspect ratio** — replace the `ConstrainedBox`/`AspectRatio` block with:

```dart
child: ConstrainedBox(
  constraints: BoxConstraints(
    maxWidth: MediaQuery.of(context).size.width * 0.92,
    maxHeight: MediaQuery.of(context).size.height * 0.7,
  ),
  child: AspectRatio(
    aspectRatio: (_initialized && (_controller?.value.aspectRatio ?? 0) > 0.01)
        ? _controller!.value.aspectRatio
        : 9 / 16,
    child: Container(
```

Everything inside stays as-is.

- [ ] **Step 2: Analyze.** **Step 3: Commit** — `git add mobile/fitness_app/lib/features/shared/widgets/proof_video_viewer.dart`

## Task 6: Ready / Live / Done status chip (concern 7)

**File:** `workout_header.dart`

- [ ] **Step 1: Add import:** `import 'package:fitness_app/app/design_tokens.dart';`

- [ ] **Step 2: Replace the color logic** (lines 19-20):

```dart
final isRunning = session.isRunning;
final isDone = session.sessionEnded;
final label = isRunning ? 'Live' : isDone ? 'Done' : 'Ready';
// Ready = purple, Live = red, Done = green (all with readable text).
final Color chipBg;
final Color chipFg;
if (isRunning) {
  chipBg = const Color(0xFFEF4444); // red — live workout
  chipFg = Colors.white;
} else if (isDone) {
  chipBg = const Color(0xFF30D158); // green — workout finished
  chipFg = const Color(0xFF052E16); // dark text stays readable on green
} else {
  chipBg = ClayTokens.clayPrimary; // purple — not started yet
  chipFg = Colors.white;
}
```

- [ ] **Step 3: Replace the chip `Container`** with:

```dart
Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: chipBg,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: chipFg.withAlpha(70)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      AnimatedPulseDot(color: chipFg, size: 6),
      const SizedBox(width: 5),
      Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: chipFg),
      ),
    ],
  ),
),
```

- [ ] **Step 4: Analyze** — no new issues; grep confirms no other reference to `liveColor`.
- [ ] **Step 5: Device test** — purple "Ready" before start, red "Live" while running, green "Done" after finishing.
- [ ] **Step 6: Commit** — `git add mobile/fitness_app/lib/features/member/workout/widgets/workout_header.dart`

## Task 7: Full verification + final commit

- [ ] **Step 1:** `flutter analyze --no-pub` → no new issues vs baseline (`No issues found!`).
- [ ] **Step 2:** `flutter build web --release` → succeeds.
- [ ] **Step 3: End-to-end device pass over all 7 concerns.**
- [ ] **Step 4:** Confirm `git status` shows only the 5 intended files — never teammates' WIP.

## Self-review

- Spec coverage: all 7 concerns → Tasks 1–6 ✓
- Placeholders: none — every step has exact code ✓
- Type consistency: `_lens`/`_cams`/`_canFlip`/`_flipCamera` identical across Tasks 3–4; `showProofVideoDialog(context, url)` signature unchanged ✓

              'Cancel',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    ],
  );
}
```

- [ ] **Step 3: Analyze** — no new issues. **Step 4: Device test** — red line directly under title; Cancel at bottom. **Step 5: Commit** — `git add mobile/fitness_app/lib/features/shared/widgets/proof_camera_screen.dart`


  border: Border.all(color: Colors.white.withAlpha(30)),
),
```

| 3 | Front & back cam + hide nav bar on recorder | Task 3 |
| 4 | Red line under "Proof Video" text | Task 4 |
| 5 | View video stretched → portrait, no stretch | Task 5 |
| 6 | Post-recording card → glass | Task 1 + Task 2 (inner strip) |
| 7 | Ready=purple / Live=red / Done=green, readable | Task 6 |
