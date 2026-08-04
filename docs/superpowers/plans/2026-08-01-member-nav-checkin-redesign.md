# Member Nav Redesign + Camera-First Check-In Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the member bottom nav with a labeled 5-tab bar (Home, Workout, **In & Out** centered, Food, Chat), delete the standalone Progress screen (merging its content into Home), and make the In & Out tab open the camera immediately with a timed check-in confirmation.

**Architecture:** The current nav is `CircleNavBar` (icon-only, no labels) in `router.dart` shells. We build a custom `MemberNavBar` (dark clay style, raised purple center button) used only by the member shell; the trainer shell keeps `CircleNavBar`. The check-in page (`CheckinPage`, shared with trainer) gains a `showBack` flag — member tab mode opens the scanner instantly and shows a full-screen "Checked in at 3:45 PM" success state that auto-returns to Home after 2s. The Progress screen's data provider logic moves into `homeDataProvider`, and the page file is deleted. The admin QR page already shows the check-in QR on the right side (`QRPage.tsx:191-195`, value `FITGYM:ATTENDANCE`) — **no admin changes needed**.

**Tech Stack:** Flutter, go_router ^14.8.0, flutter_riverpod ^2.6.1, supabase_flutter, intl, mobile_scanner, clay design tokens (`ClayTokens` in `lib/app/design_tokens.dart`).

**Verification baseline:** No `test/` directory exists in `mobile/fitness_app` — verification is `flutter analyze` (zero issues) + manual run via `run_chrome.bat`.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mobile/fitness_app/lib/features/shared/widgets/member_nav_bar.dart` | Create | 5-tab labeled bar with raised purple center button |
| `mobile/fitness_app/lib/app/router.dart` | Modify | Routes, tab index mapping, swap nav in `MemberShell`, `CheckinPage(showBack:)` |
| `mobile/fitness_app/lib/features/shared/checkin/checkin_page.dart` | Modify | Camera-first, success screen with local time, auto-return (member only) |
| `mobile/fitness_app/lib/features/member/home/pages/home_page.dart` | Modify | Provider gains month data; add month chart + summary cards; remove check-in bubble; fix `_MoreRow` |
| `mobile/fitness_app/lib/features/member/progress/pages/progress_page.dart` | Delete | Screen is gone |
| `mobile/fitness_app/lib/features/member/profile/pages/profile_page.dart` | Modify | `push('/member/checkin')` → `go(...)` (line 68) |
| `mobile/fitness_app/lib/features/member/settings/pages/settings_page.dart` | Modify | `push('/member/checkin')` → `go(...)` (line 132) |
| `admin/src/features/qr/pages/QRPage.tsx` | **No change** | Right-side check-in QR already exists |

---

## Task 1: Create `MemberNavBar` widget

**Files:**
- Create: `mobile/fitness_app/lib/features/shared/widgets/member_nav_bar.dart`

- [ ] **Step 1: Write the widget** — dark rounded bar (clay style), 4 regular items (icon + label below, active = purple), center raised circular purple button with QR icon and "In & Out" label:

```dart
import 'package:flutter/material.dart';
import '../../../app/design_tokens.dart';

class MemberNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MemberNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _tabs = [
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.fitness_center, Icons.fitness_center, 'Workout'),
    (Icons.qr_code_scanner, Icons.qr_code_scanner, 'In & Out'),
    (Icons.restaurant, Icons.restaurant, 'Food'),
    (Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    const barH = 62.0;
    const circleD = 58.0;
    final purple = ClayTokens.clayPrimary;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 8),
      child: SizedBox(
        height: barH,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Bar body
            Container(
              height: barH,
              decoration: BoxDecoration(
                color: ClayTokens.clayDarkSurface,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: ClayTokens.clayDarkBorder.withAlpha(100),
                  width: 0.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: purple.withValues(alpha: 0.25),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(5, (i) {
                  if (i == 2) {
                    // Center slot: label under raised button, reserved space
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Text(
                          _tabs[i].$3,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: ClayTokens.clayDarkTextSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  final isActive = i == currentIndex;
                  return Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(i),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isActive ? _tabs[i].$2 : _tabs[i].$1,
                            size: 24,
                            color: isActive
                                ? purple
                                : ClayTokens.clayDarkTextTertiary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _tabs[i].$3,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isActive
                                  ? ClayTokens.clayDarkTextPrimary
                                  : ClayTokens.clayDarkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Raised center button
            Positioned(
              top: -circleD * 0.42,
              child: GestureDetector(
                onTap: () => onTap(2),
                child: Container(
                  width: circleD,
                  height: circleD,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [purple, ClayTokens.clayPrimaryLight],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: purple.withValues(alpha: 0.5),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: ClayTokens.clayDarkSurface,
                      width: 4,
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify with analyzer** — `flutter analyze` (from `mobile/fitness_app`). Expected: no issues.
- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/lib/features/shared/widgets/member_nav_bar.dart
git commit -m "feat(mobile): add labeled member nav bar with raised check-in button"
```

---

## Task 2: Update router — routes, index mapping, shell swap

**Files:**
- Modify: `mobile/fitness_app/lib/app/router.dart`

- [ ] **Step 1: Remove the progress route + import** — delete `import '../features/member/progress/pages/progress_page.dart';` and `GoRoute(path: '/member/progress', pageBuilder: (_, __) => _iosPush(const ProgressPage())),`.
- [ ] **Step 2: Move member check-in into the shell** — delete the standalone `GoRoute(path: '/member/checkin', pageBuilder: (_, __) => _iosPush(const CheckinPage())),` and inside the member `ShellRoute` routes add:

```dart
GoRoute(path: '/member/checkin', pageBuilder: (_, __) => _iosPush(const CheckinPage(showBack: false))),
```

Keep `/trainer/checkin` unchanged — `CheckinPage()` with default `showBack: true`.

- [ ] **Step 3: Update `_memberIndex()`**:

```dart
int _memberIndex() {
  final location = GoRouterState.of(context).matchedLocation;
  if (location == '/member/workout') return 1;
  if (location == '/member/checkin') return 2;
  if (location == '/member/meals') return 3;
  if (location.startsWith('/member/chat')) return 4;
  return 0;
}
```

- [ ] **Step 4: Update `_onTap()`** — case 2 → `context.go('/member/checkin')`, shift meals to 3, chat to 4.
- [ ] **Step 5: Swap the bar in `MemberShell.build`** — replace the `CircleNavBar(...)` with:

```dart
bottomNavigationBar: MemberNavBar(
  currentIndex: _currentIndex,
  onTap: _onTap,
),
```

Add import: `import '../features/shared/widgets/member_nav_bar.dart';` (`CheckinPage` already imported).

- [ ] **Step 6: Trainer shell — no changes.** Confirm `TrainerShell` still uses `CircleNavBar` with 4 tabs.
- [ ] **Step 7: Verify** — `flutter analyze` → no issues.
- [ ] **Step 8: Commit**

```bash
git add mobile/fitness_app/lib/app/router.dart
git commit -m "feat(mobile): member nav tabs with centered check-in route; drop progress tab"
```

---

## Task 3: Check-in page — camera-first + timed success screen

**Files:**
- Modify: `mobile/fitness_app/lib/features/shared/checkin/checkin_page.dart`

- [ ] **Step 1: Add `showBack` param + scanner-on default + success state fields**

```dart
class CheckinPage extends ConsumerStatefulWidget {
  final bool showBack;
  const CheckinPage({super.key, this.showBack = true});
  ...
}
```

In `_CheckinPageState`: change `bool _showScanner = false;` → `bool _showScanner = true;` and add:

```dart
bool _showSuccess = false;
String? _successTitle;   // 'Checked In!' / 'Checked Out!'
String? _successTime;    // '3:45 PM'
Timer? _returnTimer;
```

Add `import 'dart:async';` and `import 'package:intl/intl.dart';`.

- [ ] **Step 2: Record + show the time on success** — in `_toggleAttendance`, before the `setState` that sets `_statusMessage`, compute local time; when `!widget.showBack`, set the success state instead:

```dart
final localTime = DateFormat('h:mm a').format(DateTime.now());
if (!widget.showBack) {
  setState(() {
    _showSuccess = true;
    _successTitle = open ? 'Checked Out!' : 'Checked In!';
    _successTime = localTime;
  });
  _returnTimer = Timer(const Duration(seconds: 2), () {
    if (mounted) context.go('/member/home');
  });
} else {
  setState(() {
    _statusMessage = open ? 'Checked out!' : 'Checked in!';
    _isSuccess = true;
  });
}
```

- [ ] **Step 3: Success screen UI** — at the top of `build`, if `_showSuccess` render the full-screen confirmation (green circle check, title, `"You checked in at $_successTime"`, "Returning to Home..." hint) and `return` it. Style with `ClayTokens.clayAccent`, `ClayTokens.darkDisplaySmall`, `ClayTokens.darkBodySmall` on `ClayTokens.clayDarkBase`.
- [ ] **Step 4: Adaptive header** — pass `showBack: widget.showBack` to `_buildHeader`; when `false`, replace the back `CupertinoButton` with a `SizedBox(width: 32)` and title "In & Out".
- [ ] **Step 5: Dispose timer** — in `dispose()`: `_returnTimer?.cancel();`
- [ ] **Step 6: Verify** — `flutter analyze` → no issues.
- [ ] **Step 7: Commit**

```bash
git add mobile/fitness_app/lib/features/shared/checkin/checkin_page.dart
git commit -m "feat(mobile): camera-first check-in with timed confirmation on member tab"
```

---

## Task 4: Home page absorbs Progress screen

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/home/pages/home_page.dart`

- [ ] **Step 1: Extend `homeDataProvider`** — after the existing week attendance block, add (logic copied from `progressDataProvider`):

```dart
final monthStart = DateTime(today.year, today.month, 1);
final monthEnd = DateTime(today.year, today.month + 1, 0).day;

final monthAttendance = await client
    .from('attendance')
    .select('check_in_time')
    .eq('member_id', userId)
    .gte('check_in_time', monthStart.toIso8601String())
    .lt('check_in_time', DateTime(today.year, today.month + 1, 1).toIso8601String());

final monthList = monthAttendance as List;
final monthCounts = List.generate(monthEnd, (i) => 0);
for (final a in monthList) {
  final t = DateTime.parse(a['check_in_time'] as String);
  final day = t.day - 1;
  if (day >= 0 && day < monthEnd) monthCounts[day]++;
}

final totalWorkouts = monthCounts.reduce((a, b) => a + b);
final activeDays = monthCounts.where((c) => c > 0).length;
```

Add to the returned map: `'monthCounts'`, `'maxMonth': monthCounts.reduce((a, b) => a > b ? a : 1).clamp(1, 100)`, `'totalWorkouts'`, `'activeDays'`, `'monthLabel': DateFormat('MMMM yyyy').format(today)`. Add `import 'package:intl/intl.dart';`.

- [ ] **Step 2: Month chart + summary section** — in `HomeContent.build`, after the `_StatRow` block insert:

```dart
StaggeredFadeIn(index: 1 + offset, child: _MonthChart(
  monthCounts: monthCounts,
  maxMonth: maxMonth,
  monthLabel: monthLabel,
)),
const SizedBox(height: 8),
StaggeredFadeIn(index: 2 + offset, child: _MonthSummary(
  totalWorkouts: totalWorkouts,
  activeDays: activeDays,
)),
const SizedBox(height: 8),
```

Extract `monthCounts`, `maxMonth`, `totalWorkouts`, `activeDays`, `monthLabel` from `data` in `build`. Adjust subsequent `index:` values to keep sequential stagger ordering.

- [ ] **Step 3: Implement `_MonthChart`** — clay-styled copy of the old month chart: `ClayCard(variant: outlined)`; title "This Month — Daily Workouts"; 70px bar row (`Expanded` bars, today = `0xFF64D2FF`, past-with-count = `0xFF0A84FF`, empty = `ClayTokens.clayDarkBorder`), caption "Bar height = workouts per day of month" in `ClayTokens.darkBodySmall`.
- [ ] **Step 4: Implement `_MonthSummary`** — `Row` with two `Expanded` `ClayCard`s reusing the `_StatCard` pattern: "Workouts this month" (icon `Icons.fitness_center`, purple, `AnimatedCountUp`) and "Active days" (icon `Icons.calendar_month`, `0xFF64D2FF`, `AnimatedCountUp`).
- [ ] **Step 5: Remove the floating check-in bubble** — delete the `Positioned(... _CheckInBubble ...)` block, the `_CheckInBubble` class, and the `go_router` usage in it (keep import — still used elsewhere).
- [ ] **Step 6: Fix `_MoreRow`** — replace the Progress tile with a Measurements tile: `icon: Icons.monitor_weight_outlined, title: 'Measurements', onTap: () => context.go('/member/measurements')`.
- [ ] **Step 7: Verify** — `flutter analyze` → no issues.
- [ ] **Step 8: Commit**

```bash
git add mobile/fitness_app/lib/features/member/home/pages/home_page.dart
git commit -m "feat(mobile): merge progress charts and stats into home screen"
```

---

## Task 5: Delete Progress screen + fix check-in references

**Files:**
- Delete: `mobile/fitness_app/lib/features/member/progress/pages/progress_page.dart`
- Modify: `mobile/fitness_app/lib/features/member/profile/pages/profile_page.dart:68`
- Modify: `mobile/fitness_app/lib/features/member/settings/pages/settings_page.dart:132`

- [ ] **Step 1: Delete the file** — `git rm mobile/fitness_app/lib/features/member/progress/pages/progress_page.dart` (empty `progress/` dirs may be removed).
- [ ] **Step 2: Update profile page** — line 68: `onTap: () => context.push('/member/checkin')` → `onTap: () => context.go('/member/checkin')`.
- [ ] **Step 3: Update settings page** — line 132: same `push` → `go` change.
- [ ] **Step 4: Verify no stale references** — `rg -n "member/progress|ProgressPage" mobile/fitness_app/lib` → no matches (only trainer's `MemberProgressPage`/`progress_list_page` should remain, untouched).
- [ ] **Step 5: Verify** — `flutter analyze` → no issues.
- [ ] **Step 6: Commit**

```bash
git add -A mobile/fitness_app/lib/features/member/progress mobile/fitness_app/lib/features/member/profile/pages/profile_page.dart mobile/fitness_app/lib/features/member/settings/pages/settings_page.dart
git commit -m "refactor(mobile): remove member progress screen; fix check-in shortcuts"
```

---

## Task 6: Verify end-to-end

- [ ] **Step 1: Static checks** — `flutter analyze` in `mobile/fitness_app` → **zero issues**.
- [ ] **Step 2: Run app** — `./run_chrome.bat` (or `flutter run -d chrome`).
- [ ] **Step 3: Manual flow test**
  1. Login as member → lands on Home; nav shows Home / Workout / **In & Out (center, raised purple circle)** / Food / Chat with labels.
  2. Tapping each tab navigates; active state highlights purple.
  3. Tap **In & Out** → camera scanner opens **immediately**, title "In & Out", no back button.
  4. Open admin app `/qr` → right-side "Check-in / Check-out" card → scan its QR with the member camera → full-screen green **"Checked In!"** + **"You checked in at 3:45 PM"** (local time) → auto-returns to Home after ~2s.
  5. Scan again → shows "Checked Out!" with time.
  6. Home now shows: This Week chart, This Month chart, month summary cards — no Progress tile in the bottom row; no floating check-in bubble.
  7. Trainer login → nav unchanged (4 tabs), trainer check-in flow still shows the old banner (no auto-return).
- [ ] **Step 4: Commit any test fixes.**

---

## Self-Review

- **Spec coverage:** 5 labeled tabs ✓ (Task 1-2); Progress screen gone, content on Home ✓ (Tasks 2, 4, 5); In & Out centered ✓ (Task 1); camera opens on tap ✓ (Task 3); admin QR on right side already exists ✓ (no admin change); time shown after scan ✓ (Task 3); trainer untouched ✓ (Task 2 step 6).
- **Placeholders:** none — all code blocks are complete.
- **Consistency:** `CheckinPage(showBack:)` default `true` (trainer) and `false` (member tab) — all call sites updated; `MemberNavBar` used only in `MemberShell`; `_MoreRow` no longer references `/member/progress`.
