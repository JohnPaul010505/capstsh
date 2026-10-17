# Member/Trainer UI Bug Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix four reported UI bugs: (1) the trainer dashboard burger-menu arrow is purple in light mode (must be white), (2) the member Goals screen's burger button disappears behind its own popup menu, (3) the trainer Member Progress overview fails with `PostgrestException column goals.target does not exist`, and (4) the member Settings "Trainer Plan" dialog shows "Active Trainer Plan" for an expired plan (and a wrong duration), making the previously claimed fix invisible.

**Architecture:** Four surgical edits in four existing Flutter files — no new files, no new packages, no data-layer changes. Each fix is derived from verified root-cause evidence (Flutter SDK source at `C:\flutter`, DB migrations, and the app's own insert code), not guesswork. Verification is `flutter analyze --no-pub` (project is currently clean: 0 issues) plus the existing `flutter test` suite.

**Tech Stack:** Flutter (material), Riverpod, Supabase (postgrest), go_router. Windows shell = PowerShell.

**Spec:** The four user-reported concerns with screenshots (trainer dashboard arrow color; Goals burger button not visible after tapping; Member Progress "Could not load this tab" error; Settings plan dialog output unchanged). Root-cause analysis is recorded per-task below.

## Global Constraints

- Working directory for all commands: `c:\capstsh\mobile\fitness_app`.
- `flutter analyze --no-pub` must end at **0 issues** (it is clean today — no regressions allowed).
- Existing tests `goal_progress_test.dart`, `light_mode_glass_test.dart`, `plan_day_test.dart` must keep passing (`flutter test`).
- **No commits** — the user's standing instruction is that changes stay uncommitted for their review (per prior session: "No commits were made, as requested").
- Touch only these files:
  1. `lib/features/trainer/dashboard/pages/dashboard_page.dart`
  2. `lib/features/member/goals/pages/goals_screen.dart`
  3. `lib/features/trainer/progress/pages/member_progress_page.dart`
  4. `lib/features/member/settings/pages/settings_page.dart`
- Dark-mode rendering stays byte-identical except where a task explicitly says "light mode".
- No new pub dependencies.

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `dashboard_page.dart` | 1-line color swap | `_BurgerMenuOverlay` arrow painter light-mode branch |
| `goals_screen.dart` | add `PopupMenuPosition.under`; delete `_modeMenuArrowX`; shape computes tip from actual rect; drop now-unused `dart:math` import | burger menu anchoring + arrow geometry |
| `member_progress_page.dart` | select columns + target rendering | trainer's goals overview query/display |
| `settings_page.dart` | date-expiry check + duration from dates | Trainer Plan dialog state machine |

## Task 1 — Trainer dashboard burger arrow: white in light mode

**Root cause:** `dashboard_page.dart:1479-1483` paints the overlay arrow with a light-mode branch of `ClayTokens.clayPrimary.withAlpha(70)` (purple). The dark branch already uses the neutral glass hairline. The user wants white in light mode; dark mode unchanged.

- [x] **Step 1: Edit the arrow painter color**

In `c:\capstsh\mobile\fitness_app\lib\features\trainer\dashboard\pages\dashboard_page.dart`, find in `_BurgerMenuOverlay.build` (lines 1477-1484):

```dart
          child: CustomPaint(
            size: const Size(arrowWidth, arrowHeight),
            painter: _MenuArrowPainter(
              ClayColors.isLightMode
                  ? ClayTokens.clayPrimary.withAlpha(70)
                  : ClayTokens.hairline.withAlpha(36),
            ),
          ),
```

Replace with:

```dart
          child: CustomPaint(
            size: const Size(arrowWidth, arrowHeight),
            painter: _MenuArrowPainter(
              ClayColors.isLightMode
                  ? Colors.white
                  : ClayTokens.hairline.withAlpha(36),
            ),
          ),
```

- [x] **Step 2: Verify**

Run: `flutter analyze --no-pub`
Expected: `No issues found!` (0 issues, same as before the edit).

Manual check (on device): trainer dashboard → tap burger → the small triangle above the dropdown panel is **white** in light mode; unchanged (hairline translucent) in dark mode; the purple glow under the panel stays (only the arrow changes).


## Task 2 — Member Goals: keep burger button visible; arrow points exactly at it

**Root cause (verified in Flutter SDK `C:\flutter\packages\flutter\lib\src\material\popup_menu.dart`):**
1. `PopupMenuButton` defaults to `PopupMenuPosition.over` (source line 1657: `widget.position ?? popupMenuTheme.position ?? PopupMenuPosition.over`), which anchors the menu's top-left at the **button's top-left + offset** (line 1661) — so the menu opens *on top of* the burger icon, hiding it. The goals code was written assuming `under` behavior (its comment: "anchors the dropdown directly beneath this button"). This is why the button "is still not visible" after tapping.
2. The prior session's "arrow fix" was a no-op: it changed `menuWidth - buttonWidth / 2` to `menuWidth - 24.0`, identical values for the 48 px button — so the output never changed. Worse, the value depends on a TextPainter *estimate* of menu width that under-counts the selected row (w600 text + checkmark ≈ 21 px short), so the arrow lands near the button's left edge.

**Fix:** force `PopupMenuPosition.under`, and compute the arrow tip from the *actual* menu rect at paint time instead of an estimate. Geometry proof (verified against SDK source):
- The burger button is the last child of a full-width `Row` with 8 px header padding → `position.right = 8 < position.left` → SDK right-aligns the menu: `x = size.width - position.right - childSize.width` (line 865), i.e. **the menu's right edge always coincides with the button's right edge**.
- Route horizontal padding is `EdgeInsets.symmetric(vertical: 8)` (defaults, lines 1824/1872) → `_fitInsideScreen` (lines 901-904) does not shift it horizontally.
- The button is a 48 px `IconButton` (icon-only → `child == null`, default `padding: EdgeInsets.all(8)`) → its centre is exactly **24 px from its right edge**.
- ⇒ correct tip local X = `rect.right - 24`, exact for every menu width.
- Vertical (`under` + SDK lines 1663/1666): route top = `button.bottom + 6 - 8/2 = button.bottom + 2`; card top adds route padding 8 → card top = `button.bottom + 10`; the 12 px arrow tip lands at `button.bottom - 2` — inside the button, pointing up at it, exactly like the reference (image 1).

- [x] **Step 1: Anchor the menu under the button**

In `goals_screen.dart`, inside `_buildHeader` at `PopupMenuButton<String>(` (line 340), add the `position` argument right after `tooltip`:

```dart
          PopupMenuButton<String>(
            tooltip: 'Switch goal type',
            position: PopupMenuPosition.under,
            color: ClayColors.isLightMode
```

- [x] **Step 2: Switch the shape to the exact dynamic arrow**

Replace the shape argument (line 348):

```dart
            shape: _MenuArrowShape(arrowX: _modeMenuArrowX(context)),
```

with:

```dart
            shape: const _MenuArrowShape(),
```

- [x] **Step 3: Rewrite `_MenuArrowShape` (drop the `arrowX` field)**

Replace the whole class (current lines 814-879, from `/// Popup menu shape with an arrow notch...` through its closing `}`) with:

```dart
/// Popup menu shape with an arrow notch at the top that points up at the
/// burger button. The menu's right edge always aligns with the button's
/// right edge (the button is the last child of a header Row padded 8px, so
/// `position.right < position.left` and Flutter right-aligns the menu; the
/// route's horizontal padding is 0), and the button is a 48px IconButton —
/// so its centre sits exactly 24px from the menu's right edge. Computing the
/// tip from the actual rect keeps the arrow exact for any menu width, with
/// no TextPainter width estimation.
class _MenuArrowShape extends ShapeBorder {
  const _MenuArrowShape();

  /// How far the arrow pokes above the menu's rounded rectangle.
  static const double _arrowHeight = 12.0;

  /// Half-width of the arrow's base along the menu's top edge.
  static const double _arrowHalfWidth = 9.0;

  static const double _edgeRadius = 14.0;

  /// Distance from the menu's right edge to the arrow's centre line
  /// (half of the 48px burger button).
  static const double _arrowFromRight = 24.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final topY = rect.top + _arrowHeight;
    final tipX = rect.right - _arrowFromRight;
    return Path()
      // Top edge: rounded top-left corner, up the arrow's left slope, down
      // the right slope, then along to the top-right corner.
      ..moveTo(rect.left + _edgeRadius, topY)
      ..lineTo(tipX - _arrowHalfWidth, topY)
      ..lineTo(tipX, topY - _arrowHeight)
      ..lineTo(tipX + _arrowHalfWidth, topY)
      ..lineTo(rect.right - _edgeRadius, topY)
      ..quadraticBezierTo(rect.right, topY, rect.right, topY + _edgeRadius)
      // Right edge + bottom-right corner.
      ..lineTo(rect.right, rect.bottom - _edgeRadius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - _edgeRadius,
        rect.bottom,
      )
      // Bottom edge + bottom-left corner.
      ..lineTo(rect.left + _edgeRadius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - _edgeRadius,
      )
      // Left edge back up to the rounded top-left corner.
      ..lineTo(rect.left, topY + _edgeRadius)
      ..quadraticBezierTo(rect.left, topY, rect.left + _edgeRadius, topY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

- [x] **Step 4: Delete `_modeMenuArrowX` and the `dart:math` import**

Delete the function `_modeMenuArrowX` **and its full doc comment** (current lines 783-812 — everything from `/// Horizontal position, measured from the menu's left edge...` through the function's closing `}`). `math.max`, `TextPainter`, and `MediaQuery.textScalerOf` are only used there (verified: `math.` appears solely on line 804), so also delete line 1:

```dart
import 'dart:math' as math;
```

`TextDirection` (used by `ShapeBorder`) is exported by `package:flutter/material.dart`, which is already imported — no other import changes.

- [x] **Step 5: Verify**

Run: `flutter analyze --no-pub`
Expected: `No issues found!` — in particular no `unused_import`, `unused_element`, or `undefined_method` errors.

Run: `flutter test`
Expected: all 3 suites pass (they do not touch this file, but confirm nothing global broke).

Manual check (on device): member Goals → burger icon ☰ visible at top-right in the header → tap it → menu drops **below** the icon with the arrow tip touching the icon's button from below, icon still visible (matches image 1's expected pattern); selecting Workout/Food still switches modes; tapping outside closes it.

## Task 3 — Trainer Member Progress: fix the goals query (`target` → `target_value`)

**Root cause:** `member_progress_page.dart:60` selects `target`, but the `goals` table column is `target_value` (migration `00001_initial_schema.sql:88`; there has never been a `target` column). Postgrest returns `42703 Bad Request` → the whole `memberProgressDataProvider` future throws → the overview tab renders "Could not load this tab" (image 3). Secondary bug: line 464 reads `goal['target'] as String?` — even with the right key, `target_value` is a `decimal` (JSON number), so a cast to `String?` would throw.

Data facts (verified from the app's own inserts):
- Workout goals (`create_goal_card.dart:238-248`): `target_value` = number, `goal_type` ∈ {'Lose Weight', 'Gain Muscle', 'Maintain Weight', …}, **no `unit` value** → unit derived like `goal_card._unitLabel` ('kg' for those three types).
- Food goals (`create_food_goal_card.dart:166-178`): `target_value` = number, `goal_category` = 'food', `unit` = 'kcal/day'.
- Both insert `status: 'active'` → the provider's `.eq('status', 'active')` filter is correct and stays.

- [x] **Step 1: Fix the select list**

Line 60 in `member_progress_page.dart`:

```dart
            .select('id, goal_category, target, end_date, status, current_value')
```

becomes:

```dart
            .select(
              'id, goal_category, goal_type, unit, target_value, end_date, status, current_value',
            )
```


- [x] **Step 2: Fix the target parsing/display in `_GoalSummaryRow`**

Replace line 464:

```dart
    final target = goal['target'] as String? ?? '';
```

with:

```dart
    final targetValue = goal['target_value'] as num?;
    final isFood = (goal['goal_category'] as String? ?? 'workout') == 'food';
    final goalType = (goal['goal_type'] as String? ?? '').toLowerCase();
    final unit = isFood
        ? (goal['unit'] as String? ?? 'kcal/day')
        : (goalType == 'lose weight' ||
                goalType == 'gain muscle' ||
                goalType == 'maintain weight')
            ? 'kg'
            : (goal['unit'] as String? ?? '');
    final target = targetValue == null
        ? 'No target set'
        : '${targetValue.toStringAsFixed(1)}${unit.isEmpty ? '' : ' $unit'}';
```

The `Text(target, …)` at line 527 and the rest of the widget stay untouched — `target` keeps its `String` type, and the format matches the member's own goal card (`goal_card.dart:159`: `Target: 65.0 kg` style).

- [x] **Step 3: Verify**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

Run: `flutter test`
Expected: all suites pass.

Manual check (on device): trainer → member → Member Progress → Overview tab now renders the "Member Goals" section with rows like `Workout Goal  [ACTIVE]  65.0 kg  Ends Nov 15, 2026` and `Food Goal  [ACTIVE]  2000.0 kcal/day` instead of "Could not load this tab". Empty state still shows "No active goals".


## Task 4 — Member Settings: Trainer Plan dialog must detect expiry and show the real duration

**Root cause (two defects, both visible in image 4):**
1. `PlanRepository.getPlanByMember` (`plan_repository.dart:326-342`) filters **only** `status = 'active'` — nothing flips `status` when a plan's window ends, so a plan that ran Oct 12 → Oct 14 still comes back with `status: 'active'` on Oct 16. The dialog's `if (status != 'active')` check therefore never fires for date-expired plans → it still shows "Active Trainer Plan" → the previously claimed message fix is invisible → "nothing happens / the output is still the same". (For contrast, `getActivePlan` at lines 16-25 *does* date-filter with `.gte('end_date', today)` — the settings dialog must behave the same way.)
2. `_ActivePlanDialog` reads `plan['total_days']`, a column that **does not exist** on `member_goal_plans` (migration `0021_trainer_plans.sql` has no such column; `total_days` only exists as a *computed* value in trainer records, `plan_repository.dart:297`) → always falls back to `?? 7` → image 4 shows "Duration: 7 days" for an Oct 12 → Oct 14 (3-day) plan.

- [x] **Step 1: Treat date-expired plans as ended**

In `settings_page.dart`, `_showTrainerPlanDialog` (line 532), replace the `data` branch:

```dart
            data: (plan) {
              if (plan == null) return _NoPlanDialog();
              final status = plan['status'] as String? ?? 'active';
              if (status != 'active') {
                return _NoPlanDialog(
                  message: 'The plan is ended. Chat your trainer to add another plan.',
                );
              }
              return _ActivePlanDialog(plan: plan);
            },
```

with:

```dart
            data: (plan) {
              if (plan == null) return const _NoPlanDialog();
              final status = plan['status'] as String? ?? 'active';
              // The DB never flips `status` when the window simply runs out
              // (getPlanByMember filters on status only), so also treat a plan
              // whose end date has passed as ended — mirroring getActivePlan's
              // `.gte('end_date', today)` window check.
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final endDate =
                  DateTime.tryParse(plan['end_date']?.toString() ?? '');
              final expired = endDate != null && endDate.isBefore(today);
              if (status != 'active' || expired) {
                return const _NoPlanDialog(
                  message:
                      'The plan is ended. Chat your trainer to add another plan.',
                );
              }
              return _ActivePlanDialog(plan: plan);
            },
```

- [x] **Step 2: Compute the duration from the actual dates**

In `_ActivePlanDialog.build` (lines 624-626), replace:

```dart
    final startDate = plan['start_date'] as String? ?? '';
    final endDate = plan['end_date'] as String? ?? '';
    final totalDays = plan['total_days'] as int? ?? 7;
```

with:

```dart
    final startDate = plan['start_date'] as String? ?? '';
    final endDate = plan['end_date'] as String? ?? '';
    // `member_goal_plans` has no total_days column — derive the window from
    // the dates (inclusive: assignPlan writes start=now, end=start+6 → 7 days).
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    final totalDays = (start != null && end != null)
        ? (end.difference(start).inDays + 1).clamp(1, 3650).toInt()
        : (plan['total_days'] as int? ?? 7);
```

The `'Start: $startDate\nEnd: $endDate\nDuration: $totalDays days'` text and the rest of the dialog stay unchanged.

- [x] **Step 3: Verify**

Run: `flutter analyze --no-pub`
Expected: `No issues found!`

Run: `flutter test`
Expected: all suites pass (`plan_day_test.dart` covers date math helpers used elsewhere — must stay green).

Manual check (on device, plan Oct 12 → Oct 14, today ≥ Oct 16): Settings → Trainer Plan → dialog now shows **"The plan is ended. Chat your trainer to add another plan."** with the "Got it" button — different output from image 4. With a plan whose window includes today (start ≤ today ≤ end): "Active Trainer Plan" with **"Duration: N days"** where `N = end - start + 1` (Oct 12 → Oct 18 shows 7) instead of the hardcoded fallback. No plan at all: "Ask your trainer to make a plan."


## Task 5 — Final verification (whole project)

- [x] **Step 1: Full analyze**

Run: `flutter analyze --no-pub` from `c:\capstsh\mobile\fitness_app`
Expected: `No issues found!`

- [x] **Step 2: Full test suite**

Run: `flutter test`
Expected: all suites pass (`goal_progress_test`, `light_mode_glass_test`, `plan_day_test`).

- [x] **Step 3: Diff audit**

Run: `git -C c:\capstsh status --short`
Expected: the only files changed vs. HEAD are the four task files plus files already dirty before this plan (`meal_log_page.dart`, `member_progress_checkins.dart`, `member_progress_nutrition.dart`, `member_progress_tabs.dart`, `member_progress_workouts.dart`, `member_charts.dart`, `goals_diff.txt` artifact, and this plan doc). **No commits created.**

- [x] **Step 4: Hand off the manual device checklist to the user**

Four spot-checks, one per screenshot: (1) dashboard burger arrow is white in light mode; (2) Goals burger icon stays visible with the menu below it; (3) Member Progress overview shows Member Goals rows, no error; (4) expired plan dialog shows the "plan is ended" message with a duration that matches the dates.

## Review Focus

| Failure mode | Owning task | Guard |
|---|---|---|
| Arrow color change accidentally alters dark mode | Task 1 | Only the `isLightMode` branch edited; dark branch kept verbatim |
| Removing `dart:math` breaks something else in goals_screen | Task 2 Steps 4-5 | Verified its sole use is line 804; analyze flags unused/undefined symbols |
| New select list references a column that doesn't exist (repeat of the original bug) | Task 3 | Every column traced to a migration: `goal_type`,`unit`,`target_value`,`current_value` (00001), `end_date` (0025), `goal_category` (0049) |
| `totalDays` static type mismatch (`num` vs `int`) | Task 4 Step 2 | `.toInt()` applied after `clamp` |
| Date parse of `end_date` ('2026-10-14' date-only string) | Task 4 | `DateTime.tryParse` handles date-only ISO strings; `null` → not expired (safe default) |
| Menu arrow lands outside the 48px button on unusual widths | Task 2 | Tip derived from actual rect (`rect.right - 24`), not an estimate — width-independent |

```
