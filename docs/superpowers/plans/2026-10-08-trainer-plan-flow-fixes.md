# Trainer Plan Flow Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix trainer Create-Plan validation UX + input limits, add a plan start date with a trainer-signed member notification, fix the member home AI forecast on Android, and make the floating plan logo draggable/resizable with a Day-1 sheet that auto-checks completed exercises.

**Architecture:** All changes are edits to existing Flutter widgets/providers plus one one-off Node script against Supabase. The floating logo gains a `FloatingLogoPosition` ChangeNotifier (shared_preferences-persisted fractions), the plan overlay gains a workout-log lookup for auto-checkmarks, and Android's manifest gains cleartext permission so the phone can reach the local AI service.

**Tech Stack:** Flutter 3.47.0 / Dart 3.13, flutter_riverpod, shared_preferences (already ^2.3.3), supabase_flutter, Node + @supabase/supabase-js (admin scripts).

**Spec:** In-chat approved design (brainstorming session 2026-10-08): Create-Plan error text removed/replaced with neutral hint; sets/reps max 2 digits; weight max 3 digits; start-date picker + notification signed `- <trainer name>`; existing plan start date → tomorrow; Android cleartext fix; logo draggable (long-press) + resizable (pinch) with persisted position/size on Workout + Meals pages; sheet always shows Day 1 with auto-checkmarks from workout logs.

## Global Constraints
- `flutter analyze --no-pub` (run from `c:\capstsh\mobile\fitness_app`) must print **No issues found!** after every task (verified baseline before Task 1).
- No new pub dependencies (shared_preferences, cupertino, flutter_riverpod already present).
- Do not touch unrelated dirty files: `router.dart`, `profile_page.dart`, `checkin_page.dart`, `glass_sign_out_dialog.dart`, `notification_popup.dart`, `dashboard_page.dart`, `give_feedback_page.dart`, `notifications_provider.dart`, `attendance_service.dart`.
- `create_plan_screen.dart` already carries prior uncommitted work (FNRI food search + notification glass panel) — it rides along in this plan's commits; it analyzes clean today.
- No secrets in committed files: the Supabase service-role key stays in gitignored `admin/.env`.
- Styling follows ClayTokens / existing glass patterns; no redesigns.
- PowerShell note: `$_` and `$var` get eaten by the command runner — write scripts to files or avoid `$` in inline commands; use `findstr`, `curl.exe --data-binary @file`.

## Review Focus
1. Gesture arena: quick tap must still open the sheet; long-press must win for drag; pinch must not steal taps.
2. Position clamping: logo stays fully on-screen; fractions survive screen rotation.
3. Notification regression: it now fires on EVERY assign (previously only with notes) — ensure no duplicate/missing `mounted` guards.
4. Auto-check name matching: case/whitespace-insensitive; `_completed` must store the ORIGINAL exercise name (row UI compares against it).
5. One-off DB script: updates the most recent plan only, printing before/after; reads keys from `admin/.env`, never hardcode.

---

## Task 1: Create Plan validation UX (neutral hint + 2-digit limits)

**Files:** `mobile/fitness_app/lib/features/trainer/set_plan/pages/create_plan_screen.dart`

- [ ] **Step 1: Replace validation messages**

Find `_validateNumeric()` (line ~1383) and replace its body:

```dart
  /// Sets / reps must be positive whole numbers. The fields are digits-only,
  /// so the only realistic failure is an empty or zero value — the hint stays
  /// neutral ("Enter sets & reps") instead of accusing the user of letters.
  String? _validateNumeric() {
    final sets = widget.setsController.text.trim();
    final reps = widget.repsController.text.trim();
    final setsValue = int.tryParse(sets);
    final repsValue = int.tryParse(reps);
    if (setsValue == null || setsValue <= 0 || repsValue == null || repsValue <= 0) {
      return 'Enter sets & reps';
    }
    return null;
  }
```

(Ruling: the weight branch is dropped — the weight field's formatter only admits digits, so `double.tryParse` can never fail there. Cost if wrong: unreachable path lost.)

- [ ] **Step 2: Neutral hint styling**

Change the hint `Text` style (line ~1774) from red to neutral gray:

```dart
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                ),
              ],
```

- [ ] **Step 3: 2-digit limit for sets and reps**

In the Sets field (line ~1714) and Reps field (line ~1738), replace:

```dart
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
```

with:

```dart
                      // Numbers only, max 2 digits (up to 99).
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}$')),
                      ],
```

(Apply the same replacement in BOTH fields. Weight keeps its existing `^\d{0,3}$`.)

- [ ] **Step 4: Run analyzer**

Run: `cd c:\capstsh\mobile\fitness_app; C:\flutter\bin\flutter.bat analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/set_plan/pages/create_plan_screen.dart
git commit -m "fix(trainer): neutral Add-hint, 2-digit sets/reps limit on create plan (incl. prior FNRI food search + notification glass work)"
```

---

## Task 2: Start date picker + trainer-signed notification

**Files:** `mobile/fitness_app/lib/features/trainer/set_plan/pages/create_plan_screen.dart`

- [ ] **Step 1: Add state + helpers to `_CreatePlanScreenState`**

After `bool _confirmReplace = false;` (line ~45) add:

```dart
  DateTime _startDate = DateTime.now();

  static const _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) => '${_monthNames[d.month - 1]} ${d.day}, ${d.year}';
```

- [ ] **Step 2: Add picker UI between Day selector and Nutrition section**

In `build()`, immediately after the `const SizedBox(height: 16),` that FOLLOWS `_DaySelector(...)` (line ~377, before `_NutritionSection(`), insert:

```dart
                          Text(
                            'START DATE',
                            style: ClayTokens.displaySmall.copyWith(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickStartDate,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(14),
                                borderRadius:
                                    BorderRadius.circular(ClayTokens.radiusMd),
                                border:
                                    Border.all(color: Colors.white.withAlpha(30)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.calendar,
                                      size: 16, color: Color(0xFF8E8E93)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _fmtDate(_startDate),
                                      style: ClayTokens.darkBodyMedium.copyWith(
                                        color: ClayTokens.clayDarkTextPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(CupertinoIcons.chevron_down,
                                      size: 16,
                                      color: ClayTokens.clayDarkTextTertiary),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
```

- [ ] **Step 3: Add the picker method (after `_addExercise`)**

```dart
  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate.isAfter(today) ? _startDate : today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) {
      setState(() => _startDate = picked);
    }
  }
```

- [ ] **Step 4: Use `_startDate` in `_assignPlan`**

Replace the two hardcoded date lines (line ~160):

```dart
        'start_date': DateTime.now().toIso8601String().split('T').first,
        'end_date': DateTime.now().add(const Duration(days: 6)).toIso8601String().split('T').first,
```

with:

```dart
        'start_date': _startDate.toIso8601String().split('T').first,
        'end_date': _startDate
            .add(const Duration(days: 6))
            .toIso8601String()
            .split('T')
            .first,
```

- [ ] **Step 5: Always notify, signed with the trainer's name**

Replace the notification block (lines ~184-191):

```dart
      if (!mounted) return;
      final notes = notesController.text.trim();
      if (notes.isNotEmpty && selectedClient != null) {
        await NotificationService().createNotification(
          userId: selectedClient!,
          title: 'Trainer Set a Plan',
          body: notes,
        );
      }
```

with:

```dart
      if (!mounted) return;
      if (selectedClient != null) {
        final trainerName = await _trainerDisplayName(client);
        final notes = notesController.text.trim();
        final body = StringBuffer(
            'Your 7-day plan starts ${_fmtDate(_startDate)}.');
        if (notes.isNotEmpty) body.write(' $notes');
        body.write('\n- $trainerName');
        await NotificationService().createNotification(
          userId: selectedClient!,
          title: 'Trainer Set a Plan',
          body: body.toString(),
        );
      }
```

- [ ] **Step 6: Add `_trainerDisplayName` (next to `_assignPlan`)**

```dart
  /// Signed name for plan notifications: the trainer's full_name, or the
  /// literal "trainer" when the profile lookup fails (never blocks assigning).
  Future<String> _trainerDisplayName(dynamic client) async {
    try {
      final id = client.auth.currentUser?.id;
      if (id == null) return 'trainer';
      final row = await client
          .from('profiles')
          .select('full_name')
          .eq('id', id)
          .maybeSingle();
      final name = row == null ? null : row['full_name'] as String?;
      if (name != null && name.trim().isNotEmpty) return name.trim();
    } catch (_) {
      // fall through to the generic signature
    }
    return 'trainer';
  }
```

- [ ] **Step 7: Run analyzer**

Run: `cd c:\capstsh\mobile\fitness_app; C:\flutter\bin\flutter.bat analyze --no-pub`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/set_plan/pages/create_plan_screen.dart
git commit -m "feat(trainer): start-date picker on create plan + always-notify member with '- trainer' signature"
```

---

## Task 3: One-off — push the existing plan's start date to tomorrow

**Files (new):** `admin/scripts/set-plan-start-tomorrow.mjs`

- [ ] **Step 1: Verify admin/.env has SUPABASE_URL**

Run: `findstr /I /C:"SUPABASE_URL" c:\capstsh\admin\.env`
Expected: a `SUPABASE_URL=` line (service key already confirmed present).

- [ ] **Step 2: Create the script**

```js
// One-off: push the MOST RECENT member_goal_plans row's start_date to tomorrow
// (end_date = start + 6). Keys come from admin/.env — never hardcoded.
// Run: node scripts/set-plan-start-tomorrow.mjs   (from admin/)
import { config } from 'dotenv'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import { createClient } from '@supabase/supabase-js'

config({ path: resolve(dirname(fileURLToPath(import.meta.url)), '..', '.env') })

const db = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY)

const { data: plans, error } = await db
  .from('member_goal_plans')
  .select('id, member_id, start_date, end_date')
  .order('created_at', { ascending: false })
  .limit(1)
if (error) throw error
if (!plans || plans.length === 0) {
  console.log('No plans found — nothing to update.')
  process.exit(0)
}

const plan = plans[0]
const pad = (n) => String(n).padStart(2, '0')
const start = new Date()
start.setDate(start.getDate() + 1)
const end = new Date(start)
end.setDate(end.getDate() + 6)
const startStr = `${start.getFullYear()}-${pad(start.getMonth() + 1)}-${pad(start.getDate())}`
const endStr = `${end.getFullYear()}-${pad(end.getMonth() + 1)}-${pad(end.getDate())}`

const { error: upErr } = await db
  .from('member_goal_plans')
  .update({ start_date: startStr, end_date: endStr, updated_at: new Date().toISOString() })
  .eq('id', plan.id)
if (upErr) throw upErr

console.log(
  `Updated plan ${plan.id} (member ${plan.member_id}): ` +
    `${plan.start_date} -> ${startStr}, ${plan.end_date} -> ${endStr}`,
)
```

- [ ] **Step 3: Run the script**

Run: `cd c:\capstsh\admin; node scripts/set-plan-start-tomorrow.mjs`
Expected: prints `Updated plan <id> (member <id>): <old> -> 2026-10-09, <old> -> 2026-10-15`.

- [ ] **Step 4: Commit**

```bash
git add admin/scripts/set-plan-start-tomorrow.mjs
git commit -m "chore(admin): one-off script pushing latest plan start_date to tomorrow"
```

---

## Task 4: Android cleartext HTTP for the AI forecast

**Files:** `mobile/fitness_app/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Add usesCleartextTraffic**

Change:

```xml
    <application
        android:label="fitness_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
```

to:

```xml
    <application
        android:label="fitness_app"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true">
```

(Why: AI service lives at `http://192.168.100.181:3001` — plain HTTP. Verified reachable from this PC; Android 9+ silently blocks cleartext, which is why the member home forecast card shows "Could not reach the prediction service".)

- [ ] **Step 2: Grep sanity**

Run: `findstr /I /C:"usesCleartextTraffic" c:\capstsh\mobile\fitness_app\android\app\src\main\AndroidManifest.xml`
Expected: one matching line.

- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/android/app/src/main/AndroidManifest.xml
git commit -m "fix(android): allow cleartext HTTP so member AI forecast reaches LAN AI service"
```

---

## Task 5: Draggable + resizable floating logo (Workout + Meals)

**Files:** `mobile/fitness_app/lib/features/shared/providers/plan_providers.dart`, `mobile/fitness_app/lib/features/shared/widgets/plan_floating_logo.dart`, `mobile/fitness_app/lib/features/member/workout/pages/workout_page.dart`, `mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart`

- [ ] **Step 1: Add `FloatingLogoPosition` to `plan_providers.dart`**

The file currently imports only `flutter/foundation.dart` — add `import 'package:flutter/material.dart';` (for Offset/Size) and `import 'package:shared_preferences/shared_preferences.dart';`. Append after `planOverlayControllerProvider`:

```dart
/// Fraction-based position + size of the member's floating plan logo.
/// Stored as fractions of the screen so rotation/resolution never breaks it;
/// `fraction == null` means "default spot" (right:16, bottom:96).
class FloatingLogoPosition extends ChangeNotifier {
  Offset? _fraction;
  double _size = 52;
  bool _loaded = false;

  Offset? get fraction => _fraction;
  double get size => _size;

  Offset _dragStartPoint = Offset.zero;
  Offset _dragStartFraction = Offset.zero;
  double _dragStartSize = 52;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _size = (prefs.getDouble('plan_logo_size') ?? 52).clamp(44.0, 96.0);
      final x = prefs.getDouble('plan_logo_x');
      final y = prefs.getDouble('plan_logo_y');
      if (x != null && y != null) _fraction = Offset(x, y);
    } catch (_) {
      // Defaults are fine when prefs are unavailable.
    }
  }

  Offset defaultFraction(Size screen) => Offset(
        (screen.width - _size - 16) / screen.width,
        (screen.height - _size - 96) / screen.height,
      );

  void beginDrag(Offset globalPoint, Size screen) {
    _dragStartPoint = globalPoint;
    _dragStartFraction = _fraction ?? defaultFraction(screen);
  }

  void dragTo(Offset globalPoint, Size screen) {
    final delta = globalPoint - _dragStartPoint;
    final maxX = (screen.width - _size - 8) / screen.width;
    final maxY = (screen.height - _size - 8) / screen.height;
    _fraction = Offset(
      (_dragStartFraction.dx + delta.dx / screen.width).clamp(0.0, maxX),
      (_dragStartFraction.dy + delta.dy / screen.height).clamp(0.0, maxY),
    );
    notifyListeners();
  }

  void beginScale() => _dragStartSize = _size;

  void scaleTo(double scale, Size screen) {
    final maxDim = screen.width < screen.height ? screen.width : screen.height;
    final cap = maxDim - 16 < 96 ? maxDim - 16 : 96.0;
    _size = (_dragStartSize * scale).clamp(44.0, cap);
    notifyListeners();
  }

  Future<void> persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('plan_logo_size', _size);
      final f = _fraction;
      if (f != null) {
        await prefs.setDouble('plan_logo_x', f.dx);
        await prefs.setDouble('plan_logo_y', f.dy);
      }
    } catch (_) {
      // Persistence is best-effort.
    }
  }
}

final floatingLogoPositionProvider =
    ChangeNotifierProvider<FloatingLogoPosition>((ref) {
  final position = FloatingLogoPosition();
  position.load();
  return position;
});
```

- [ ] **Step 2: Rewrite `plan_floating_logo.dart`**

Replace the whole file with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/design_tokens.dart';
import '../providers/plan_providers.dart';

/// Member's floating trainer-plan logo.
/// - quick tap         -> onTap (opens the Day-1 sheet)
/// - long-press + drag -> move anywhere on screen
/// - two-finger pinch  -> resize (44-96 px)
/// Position/size persist across pages via [floatingLogoPositionProvider].
class PlanFloatingLogo extends ConsumerWidget {
  final VoidCallback onTap;
  final bool isExpanded;
  final String memberId;

  const PlanFloatingLogo({
    super.key,
    required this.onTap,
    required this.isExpanded,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(floatingLogoPositionProvider);
    final size = position.size;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPressStart: (details) => position.beginDrag(
          details.globalPosition, MediaQuery.sizeOf(context)),
      onLongPressMoveUpdate: (details) => position.dragTo(
          details.globalPosition, MediaQuery.sizeOf(context)),
      onLongPressEnd: (_) => position.persist(),
      onScaleStart: (_) => position.beginScale(),
      onScaleUpdate: (details) {
        if (details.pointerCount >= 2) {
          position.scaleTo(details.scale, MediaQuery.sizeOf(context));
        }
      },
      onScaleEnd: (_) => position.persist(),
      child: AnimatedRotation(
        turns: isExpanded ? 1 : 0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [ClayTokens.clayPrimary, ClayTokens.clayPrimaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: ClayTokens.clayPrimary.withAlpha(100),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                Icons.fitness_center,
                color: Colors.white,
                size: size * 0.46,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Re-wire the Workout page position (workout_page.dart lines ~228-265)**

Replace the existing `if (ref.watch(hasActivePlanProvider)...` `Positioned(...)` block with:

```dart
                Positioned.fill(
                  child: Consumer(
                    builder: (context, ref, _) {
                      if (!(ref.watch(hasActivePlanProvider).value ?? false)) {
                        return const SizedBox.shrink();
                      }
                      final logoPos = ref.watch(floatingLogoPositionProvider);
                      final screen = MediaQuery.sizeOf(context);
                      final logo = PlanFloatingLogo(
                        memberId:
                            SupabaseClientService().client.auth.currentUser!.id,
                        isExpanded:
                            ref.watch(planOverlayControllerProvider).isOpen,
                        onTap: () {
                          final overlay =
                              ref.read(planOverlayControllerProvider);
                          final planAsync = ref.read(activePlanProvider);
                          final plan = planAsync.value;
                          if (plan == null) return;

                          if (overlay.isOpen) {
                            overlay.close();
                          } else {
                            overlay.openForWorkout(
                              SupabaseClientService()
                                  .client
                                  .auth
                                  .currentUser!
                                  .id,
                              plan['start_date'] as String? ?? '',
                            );
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => TrainerPlanWorkoutOverlay(
                                planId: plan['id'] as String,
                                dayNumber: 1, // Day 1 only, per design
                                notes: plan['notes'] as String?,
                              ),
                            ).then((_) {
                              if (overlay.isOpen) {
                                overlay.close();
                              }
                            });
                          }
                        },
                      );
                      final f = logoPos.fraction;
                      return Stack(
                        children: [
                          if (f == null)
                            Positioned(right: 16, bottom: 96, child: logo)
                          else
                            Positioned(
                              left: f.dx * screen.width,
                              top: f.dy * screen.height,
                              child: logo,
                            ),
                        ],
                      );
                    },
                  ),
                ),
```

(Keep it inside the same `Stack` where the old `Positioned` sat. `Positioned.fill` is a direct Stack child so drag updates rebuild only this Consumer subtree, not the whole page.)

## Ledger

(Appended per task during execution.)

