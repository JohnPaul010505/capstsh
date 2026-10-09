# Trainer Dashboard — Charts, Feed & Glass Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: **`impeccable`** FIRST (design direction for all visual tasks), then `superpowers:executing-plans` (or `superpowers:subagent-driven-development`) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the three trainer dashboard screens so charts are readable and data is visible, the donut looks good, KPI cards are equal size, feeds page at 8 rows with purple Prev/Next, the burger menu matches the notification glass (purple icon, no purple box), and the date picker is glass.

**Architecture:** All changes live in one file — `mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart` (2,730 lines) — reusing two existing design recipes: the **notification-popup glass** (`notification_popup.dart` lines 290–327) and the `ClayTokens` palette. No new packages, no new files, no data-layer changes.

**Tech Stack:** Flutter, fl_chart ^0.70.0 (verified against installed 0.70.2), Riverpod, ClayTokens/GlassPanel design system.

**Spec:** No separate spec doc — the user's 6 requests are enumerated in Global Constraints.

**Design skill:** In Act mode, invoke **`impeccable`** before starting; it governs any fine visual tuning (spacing/alpha/typography) within the anchors given below.

## Global Constraints

1. Single file touched: `c:\capstsh\mobile\fitness_app\lib\features\trainer\dashboard\pages\dashboard_page.dart` (except the baseline commit).
2. Palette: `ClayTokens.clayPrimary #7C3AED`, `clayPrimaryLight #A78BFA`, `clayDarkTextPrimary #ECECFC`, `clayDarkTextSecondary #B4B4D0`, `clayDarkTextTertiary #7070A0`, `clayDarkSurfaceElevated #1C1C35`, `clayDarkBorder #2A2A45`.
3. Notification-glass recipe (copy exactly): blur 24, gradient `[#14142A@150, #221A4A@120, #14142A@160]` top→bottom stops 0/0.55/1, border `Colors.white.withAlpha(38)`, radius 16, shadows `black@105 blur24 offset(0,10)` + `clayPrimary@36 blur44 offset(0,4)`.
4. Verification command after every task: `cd c:/capstsh/mobile/fitness_app && flutter analyze --no-pub` → **0 errors in dashboard_page.dart** (the repo's ~13 pre-existing `withOpacity` infos elsewhere are acceptable).
5. Repo convention: commit directly to `main` after each task; no tests exist under `fitness_app/test/` (empty) — verification is analyze + manual run.
6. The working tree currently has **uncommitted WIP** (12 files + migration 0039) — commit it as a baseline before touching anything.

## Review Focus

1. **`IntrinsicHeight` + `CrossAxisAlignment.stretch`** in `_KpiGrid` must not throw inside the `ListView` — exercised by Task 1's run step.
2. **Static bar tooltips** (`showingTooltipIndicators`) must be capped at ≤14 buckets so labels never overlap on wide ranges — guarded in Task 3.
3. **Transparent date-picker background** keeps text readable (gradient alpha ≥150) and Cancel/OK clickable — Task 6 run step.
4. **Burger `OverlayEntry`** barrier + cleanup (`dispose` removes `_menuOverlay`) must still work after the panel swap — Task 5.
5. **Page-size 10→8** with a retained `_page` — `clamp` + `didUpdateWidget` reset must show `Showing 1–8 of N` and never out-of-range — Task 2.

---

## Task 0 — Baseline commit of existing WIP

- [x] **Step 1: Commit current uncommitted work**

```bash
git add -A
git commit -m "wip(trainer): dashboard 3-screen redesign + realtime publication migration"
```

Expected: 12 modified Dart files + `supabase/migrations/0039_enable_realtime_publication.sql` committed; `git status --short` clean.

---

## Task 1 — Equal-size KPI cards (Daily Check-ins, Member Overview, Recent Activity)

**Problem:** `_KpiGrid` rows use the default `CrossAxisAlignment.center`, so a card with a `sub:` caption (e.g. "AVG / DAY / over 7 days") is taller than its neighbor and the two cards don't match.

- [x] **Step 1: Make each row stretch to the tallest card** — in `_KpiGrid.build` (line ~277) replace the `Row(...)` with:

```dart
rows.add(
  IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: cards[i]),
        const SizedBox(width: 8),
        if (i + 1 < cards.length) Expanded(child: cards[i + 1]),
      ],
    ),
  ),
);
```

- [x] **Step 2: Top-align card content** — in `_KpiCard.build` (line ~74), change the inner `Row(` to:

```dart
child: Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
```

(keeps icon/value baselines aligned across the now-equal-height siblings).

- [x] **Step 3: Verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze --no-pub lib/features/trainer/dashboard/pages/dashboard_page.dart
```
Expected: no errors. Run the app and confirm all four KPI cards in each of the three screens have identical heights per row.

- [x] **Step 4: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "fix(trainer): equal-height KPI cards across dashboard screens"
```

---

## Task 2 — Feed shows 8 rows/page; Prev/Next become purple

- [x] **Step 1: Page size 8** — change both class constants:

  - `_DailyCheckinsViewState` (line ~1474): `static const _pageSize = 10;` → `static const _pageSize = 8;`
  - `_RecentActivityViewState` (line ~2417): `static const _pageSize = 10;` → `static const _pageSize = 8;`

- [x] **Step 2: Purple pager buttons** — in `_PagerBtn.build` (line ~1278) replace the decoration and text style with:

```dart
decoration: BoxDecoration(
  color: enabled ? ClayTokens.clayPrimary : Colors.white.withAlpha(6),
  borderRadius: BorderRadius.circular(8),
  border: Border.all(
    color: enabled ? ClayTokens.clayPrimary : Colors.white.withAlpha(12),
  ),
),
child: Text(
  label,
  style: TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    color: enabled ? Colors.white : ClayTokens.clayDarkTextTertiary,
  ),
),
```

and bump the padding to `EdgeInsets.symmetric(horizontal: 12, vertical: 6)` for a bigger tap target. Enabled = solid purple pill (same vocabulary as the selected preset chip); disabled stays muted.

- [x] **Step 3: Verify** — `flutter analyze --no-pub` clean; run app → Activity Feed on **both** screens shows exactly 8 rows, footer reads `Showing 1–8 of N`, Prev disabled on page 1, Next disabled on last page, both buttons purple when enabled.

- [x] **Step 4: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "feat(trainer): feed pages at 8 records + purple prev/next controls"
```

---

## Task 3 — Activity Trend chart: readable, data seeable (both screens)

All in `_TrendChart` (line ~1854) — the shared widget behind Daily Check-ins **and** Recent Activity.

- [x] **Step 1: Nice y-axis ticks** — add a top-level helper above `_TrendChart`:

```dart
/// Smallest human-friendly tick (1, 2, 5, 10, 20, 25, 50, 100…) ≥ raw, so the
/// y-axis never shows ugly values like 23/46 or duplicate 1/1/1 labels.
int _trendNiceStep(int raw) {
  const steps = [
    1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500,
    5000, 10000, 20000, 25000, 50000, 100000,
  ];
  for (final s in steps) {
    if (s >= raw) return s;
  }
  return raw;
}
```

- [x] **Step 2: Rewrite `_TrendChart.build` metrics** — replace the first lines (current 1861–1865) with:

```dart
final maxCount = buckets.fold<int>(0, (p, b) => b.count > p ? b.count : p);
final rawMaxY = (maxCount == 0 ? 1 : maxCount).toDouble() * 1.3;
final leftInterval = _trendNiceStep((rawMaxY / 3).ceil());
final maxY = (rawMaxY / leftInterval).ceilToDouble() * leftInterval;
final perBar = buckets.length > 20 ? 16.0 : 26.0;
final barWidth = (perBar - 8).clamp(4.0, 16.0);
final showValues = buckets.length <= 14; // static value labels only when they fit
```

- [x] **Step 3: Taller chart, bigger labels** — inside the widget:
  - `SizedBox(height: 160, …)` → `SizedBox(height: 180, …)`
  - `horizontalInterval: leftInterval` stays but `leftInterval` is now int — use `leftInterval.toDouble()`
  - left titles: `reservedSize: 24` → `reservedSize: 30`, tick `fontSize: 9` → `11`
  - bottom titles: `reservedSize: 22` → `reservedSize: 26`, tick `fontSize: 9` → `11`
  - grid line color unchanged.

- [x] **Step 4: Gradient bars + value labels + tap tooltip** — replace `barTouchData` and `barGroups`:

```dart
barTouchData: BarTouchData(
  enabled: true,
  touchTooltipData: BarTouchTooltipData(
    tooltipRoundedRadius: 10,
    getTooltipColor: (_) => const Color(0xFF1C1C35),
    getTooltipItem: (group, groupIndex, rod, rodIndex) => BarTooltipItem(
      '${buckets[group.x].count}',
      TextStyle(
        color: ClayTokens.clayDarkTextPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 11,
      ),
    ),
  ),
),
```

```dart
barGroups: List.generate(
  buckets.length,
  (i) => BarChartGroupData(
    x: i,
    showingTooltipIndicators: showValues ? const [0] : null,
    barRods: [
      BarChartRodData(
        toY: buckets[i].count.toDouble(),
        width: barWidth,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ClayTokens.clayPrimaryLight, ClayTokens.clayPrimary],
        ),
      ),
    ],
  ),
),
```

**Effect:** every bar wears its count above it on short ranges (7-day view = instant readability); long "All time" ranges keep tap-to-inspect; grid lines land on 1/2/5/10… so y-labels are unique and legible; bars gain a purple gradient instead of flat fill.

- [x] **Step 5: Verify** — `flutter analyze --no-pub` clean; run app → Daily Check-ins (Last 7 days): y-axis shows values like 0/1/2 (no repeats), count visible on the bar; Recent Activity (All time): no overlapping labels, tap a bar → dark glass tooltip with the count.

- [x] **Step 6: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "feat(trainer): readable trend chart with nice ticks + value labels"
```

---
## Task 4 — Member Distribution donut redesign (Member Overview)

- [x] **Step 1: Brand-aligned colors** — in `_DistributionCard` (line ~2161) replace:

```dart
static const _maleColor = Color(0xFF7C3AED);      // brand purple (was blue #5B8DEF)
static const _femaleColor = Color(0xFFF472B6);    // softer pink (was #E879B9)
static const _unspecifiedColor = Color(0xFF7070A0);
static const _activeColor = Color(0xFF30D158);
static const _inactiveColor = Color(0xFFFF9F0A);
```

- [x] **Step 2: Thicker rings, slightly larger donut** — `SizedBox(height: 190, width: 190)` → `SizedBox(height: 200, width: 200)`; gender sections `radius: 24` → `radius: 26`; status sections `radius: 12` → `radius: 14` (fl_chart: `radius` = ring **thickness** added to `centerSpaceRadius` — verified in 0.70.2 source: outer = `centerRadius + section.radius`, so 44+14 = 58 < 60 keeps the inner ring nested with a 2px gap).

- [x] **Step 3: Center = active rate** (matches the admin dashboard's verified convention) — replace the center `Column` children (lines ~2265–2284) with:

```dart
Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    Text(
      '${data.total > 0 ? ((data.active / data.total) * 100).round() : 0}%',
      style: ClayTokens.headlineMedium.copyWith(
        fontWeight: FontWeight.w800,
        color: ClayTokens.clayDarkTextPrimary,
      ),
    ),
    const SizedBox(height: 1),
    Text(
      'active',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: ClayTokens.clayDarkTextTertiary,
      ),
    ),
    Text(
      'of ${data.total} members',
      style: TextStyle(
        fontSize: 9,
        color: ClayTokens.clayDarkTextTertiary,
      ),
    ),
  ],
),
```

(The header already shows `N total`, so the center now carries new information instead of repeating it.)

- [x] **Step 4: Legend rows become proportion bars** — in `_LegendGroup.build` replace the `...items.map(...)` block with:

```dart
...items.map((e) {
  final frac = sum > 0 ? (e.$2 / sum) : 0.0;
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: e.$3, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.$1,
                style: TextStyle(
                  fontSize: 12.5,
                  color: ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ),
            Text(
              '${e.$2}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: ClayTokens.clayDarkTextPrimary,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 34,
              child: Text(
                '${(frac * 100).round()}%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 11,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Container(
          height: 4,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(18),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            widthFactor: frac.clamp(0.0, 1.0),
            heightFactor: 1,
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                color: e.$3,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}),
```

- [x] **Step 5: Verify** — `flutter analyze --no-pub` clean; run app → Member Overview: donut is purple/pink/gray + green/amber, center reads `X% / active / of N members`, each legend row has a filled proportion bar, everything fits inside the card with no overflow.

- [x] **Step 6: Commit**

## Task 5 — Burger menu: notification glass panel + purple icon (no purple box)

- [x] **Step 1: Burger button active state** — replace `_buildBurger` (line ~1115) with the notification-bell treatment (icon tint only, transparent background):

```dart
Widget _buildBurger() {
  return GestureDetector(
    key: _burgerKey,
    onTap: _isMenuOpen ? _closeBurgerMenu : _openBurgerMenu,
    behavior: HitTestBehavior.opaque,
    child: Padding(
      padding: const EdgeInsets.all(6),
      child: Icon(
        Icons.menu,
        color: _isMenuOpen
            ? ClayTokens.clayPrimary
            : ClayTokens.clayDarkTextPrimary,
        size: 22,
      ),
    ),
  );
}
```

- [x] **Step 2: Swap the panel to the notification glass recipe** — in `_BurgerMenuOverlay.build` replace the inner panel `Positioned` (current lines 1375–1394, the `child: GlassPanel(...)` block) with:

```dart
Positioned(
  top: panelTop + arrowHeight,
  left: panelLeft,
  width: panelWidth,
  child: Material(
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(105),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: ClayTokens.clayPrimary.withAlpha(36),
            blurRadius: 44,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF14142A).withAlpha(150),
                  const Color(0xFF221A4A).withAlpha(120),
                  const Color(0xFF14142A).withAlpha(160),
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(38)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _menuRow(0, 'Daily Check-ins'),
                _menuRow(1, 'Member Overview'),
                _menuRow(2, 'Recent Activity'),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
```

Keep `_MenuArrowPainter(Colors.white.withAlpha(36))` (already identical to the notification arrow) and `_menuRow` unchanged. `dart:ui` is already imported (line 1).

- [x] **Step 3: Verify** — `flutter analyze --no-pub` clean; run app → tapping the burger: icon turns purple **with no purple background square**; the dropdown panel now has the same dark translucent gradient + white rim + dual glow as the Notifications popup; tapping outside still closes it; dispose with the menu open leaks nothing.

## Task 6 — Date picker: glass style like the notification popup

- [x] **Step 1: Restyle `_pickDate`'s `builder`** — replace lines ~932–956 with:

```dart
builder: (context, child) => Theme(
  data: Theme.of(context).copyWith(
    colorScheme: const ColorScheme.dark(
      primary: ClayTokens.clayPrimary,
      onPrimary: Colors.white,
      surface: ClayTokens.clayDarkSurfaceElevated,
      onSurface: ClayTokens.clayDarkTextPrimary,
    ),
    // Glass calendar: transparent surface so the notification-glass gradient
    // behind it shows through — same liquid-glass system as the popups.
    datePickerTheme: DatePickerThemeData(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    ),
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF14142A).withAlpha(175),
              const Color(0xFF221A4A).withAlpha(145),
              const Color(0xFF14142A).withAlpha(185),
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withAlpha(38)),
        ),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  ),
),
```

(Alphas run 175/145/185 rather than the popup's 150/120/160 because a calendar needs more contrast to stay readable — `impeccable` may tune these during the Act-mode design pass. Note `ColorScheme.dark(...)` becomes `const` because all its arguments are now literals.)

- [x] **Step 2: Verify** — `flutter analyze --no-pub` clean; run app → Daily Check-ins → tap **Start date**: dialog floats over a blurred backdrop with the translucent navy→indigo→navy gradient, white rim, rounded 20 corners; month navigation, day selection, Cancel/OK all still work and apply the range.

- [x] **Step 3: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "feat(trainer): glass date picker matching notification popup"
```

---

## Task 7 — Final design pass (impeccable) + verification

- [x] **Step 1:** Run the **`impeccable`** design pass over all three screens (Daily Check-ins, Member Overview, Recent Activity) + burger menu + date picker; tune only spacing/alpha/typography within Global Constraints — no structural changes. Run the mechanical detector once over changed targets: `C:\Users\Kasandra\.cline\skills\impeccable\scripts\impeccable.cmd detect --json <changed targets>`.
- [x] **Step 2: Full verification**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze --no-pub
```
Expected: 0 errors in `dashboard_page.dart`. Manual checklist: equal KPI rows ✓, 8-row feeds with purple Prev/Next ✓, labeled readable charts ✓, new donut ✓, burger purple-icon-no-box + glass panel ✓, glass date picker ✓.
- [x] **Step 3: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart docs/superpowers/plans/2026-10-08-trainer-dashboard-charts-feed-glass.md
git commit -m "polish(trainer): dashboard design pass + implementation plan"
```

- [x] **Step 4: Commit**

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "feat(trainer): burger menu uses notification glass; active icon purple without box"
```

---

```bash
git add mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "feat(trainer): redesigned member distribution donut + proportion legends"
```

---

