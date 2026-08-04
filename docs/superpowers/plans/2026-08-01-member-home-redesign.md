# Member Home Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip the member home to a clean, admin-style analytics screen: greeting → membership → **This Week** → **This Month** (area chart, x = Jan–Dec, admin "Daily Check-ins" style) → month summary cards → **Growth Over Time** (weight per month, admin "Growth" style) → trainer card.

**Architecture:** One new reusable `ClayAreaChart` widget (CustomPainter area + dashed grid + dots, labels rendered below — mirrors admin recharts AreaChart in Flutter, matching the codebase's clay bar-chart style). `homeDataProvider` is slimmed from 8 queries to 2: one yearly `attendance` fetch (derives week counts, per-month counts, current-month daily counts → totals) + one `body_measurements` fetch (per-month weight). Old widgets `_TodayProgress`, `_QuickLogRow`, `_MoreRow`, `_StatRow`, `_MonthChart` are removed (`_StatCard` stays — `_MonthSummary` uses it).

**Tech Stack:** Flutter, flutter_riverpod, supabase_flutter, ClayTokens, CustomPainter (no chart package needed).

**Branch:** `feature/member-home-redesign` created from `feature/member-nav-checkin` (carries the nav work).

**Final home order:** Greeting → Membership card → This Week → **This Month** (area, Jan–Dec) → Summary cards (Workouts this month / Active days) → **Growth Over Time** (weight/month, purple area + dots) → Trainer card.

**Verification baseline:** No `test/` directory — verification is `flutter analyze` (zero new issues) + `flutter build web --release` + manual run.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mobile/fitness_app/lib/features/shared/widgets/clay_area_chart.dart` | Create | Reusable area chart (values + labels + stroke color) |
| `mobile/fitness_app/lib/features/member/home/pages/home_page.dart` | Modify | Provider slimming (Task 2), body rebuild (Task 3) |

---

## Task 1: Create reusable `ClayAreaChart` widget

**Files:**
- Create: `mobile/fitness_app/lib/features/shared/widgets/clay_area_chart.dart`

- [ ] **Step 1: Write the widget** — input: `List<double?> values` (null = gap), `List<String> labels`, `Color strokeColor`, `double height`, `String emptyMessage`. Paints: dashed horizontal grid lines (3), polyline path + gradient fill (stroke color → transparent), dots at data points with white ring. Labels rendered as a `Row` of `Expanded` `Text`s below. Empty (all null) state: "No data yet" center text.

```dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../app/design_tokens.dart';

class ClayAreaChart extends StatelessWidget {
  final List<double?> values;
  final List<String> labels;
  final Color strokeColor;
  final double height;
  final String emptyMessage;

  const ClayAreaChart({
    super.key,
    required this.values,
    required this.labels,
    required this.strokeColor,
    this.height = 90,
    this.emptyMessage = 'No data yet',
  });

  @override
  Widget build(BuildContext context) {
    final nonNull = values.whereType<double>().toList();
    return Column(
      children: [
        SizedBox(
          height: height,
          child: nonNull.isEmpty
              ? Center(
                  child: Text(emptyMessage,
                      style: ClayTokens.darkBodySmall
                          .copyWith(color: ClayTokens.clayDarkTextTertiary)))
              : CustomPaint(
                  size: Size(double.infinity, height),
                  painter: _AreaChartPainter(
                    values: values,
                    strokeColor: strokeColor,
                    minY: nonNull.reduce(min),
                    maxY: nonNull.reduce(max),
                  ),
                ),
        ),
        const SizedBox(height: 6),
        Row(
          children: List.generate(labels.length, (i) => Expanded(
            child: Text(labels[i], textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: ClayTokens.clayDarkTextTertiary)),
          )),
        ),
      ],
    );
  }
}

class _AreaChartPainter extends CustomPainter {
  final List<double?> values;
  final Color strokeColor;
  final double minY;
  final double maxY;

  _AreaChartPainter({required this.values, required this.strokeColor, required this.minY, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    final range = (maxY - minY).clamp(0.1, double.infinity).toDouble();
    final pad = size.height * 0.08;
    double xFor(int i) => values.length == 1 ? size.width / 2 : i * size.width / (values.length - 1);
    double yFor(double v) => pad + (1 - (v - minY) / range) * (size.height - pad * 2);

    // dashed grid
    final gridPaint = Paint()
      ..color = ClayTokens.clayDarkBorder.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final f in [0.25, 0.5, 0.75]) {
      final y = size.height * f;
      for (double x = 0; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 3, size.width), y), gridPaint);
      }
    }

    // points
    final pts = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) continue;
      pts.add(Offset(xFor(i), yFor(v)));
    }
    if (pts.isEmpty) return;

    // fill
    final path = Path()..moveTo(pts.first.dx, size.height);
    for (final p in pts) {
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(pts.last.dx, size.height)..close();
    canvas.drawPath(path, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [strokeColor.withValues(alpha: 0.25), strokeColor.withValues(alpha: 0.02)],
      ).createShader(Offset.zero & size));

    // line + dots
    final linePaint = Paint()
      ..color = strokeColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(Path()..moveTo(pts.first.dx, pts.first.dy)..addPolygon(pts, false), linePaint);
    for (final p in pts) {
      canvas.drawCircle(p, 3, Paint()..color = strokeColor);
      canvas.drawCircle(p, 3, Paint()
        ..color = Colors.white
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter old) =>
      old.values != values || old.strokeColor != strokeColor || old.minY != minY || old.maxY != maxY;
}
```

- [ ] **Step 2:** `flutter analyze` from `C:\capshii\capshii\mobile\fitness_app` → clean (13 pre-existing infos OK).
- [ ] **Step 3: Commit** from repo root: `git add mobile/fitness_app/lib/features/shared/widgets/clay_area_chart.dart` && `git commit -m "feat(mobile): add reusable clay area chart widget"`

---

## Task 2: Slim `homeDataProvider` to 2 main queries

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/home/pages/home_page.dart`

- [ ] **Step 1: Rewrite the provider.** Replace all attendance/measurements fetches (currently ~8 sequential queries: week attendance, month attendance, measurements, goals, assignment+trainer, membership, open session) with:

```dart
final homeDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final client = SupabaseClientService().client;
  final profile = ref.watch(authProvider).valueOrNull;
  final today = DateTime.now();
  final yearStart = DateTime(today.year, 1, 1);
  final nextYear = DateTime(today.year + 1, 1, 1);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final monthStart = DateTime(today.year, today.month, 1);
  final monthEnd = DateTime(today.year, today.month + 1, 0).day;

  // ONE attendance query: whole year -> week counts, monthly counts (Jan..Dec), current-month daily counts
  final yearAttendance = await client
      .from('attendance')
      .select('check_in_time')
      .eq('member_id', userId)
      .gte('check_in_time', yearStart.toIso8601String())
      .lt('check_in_time', nextYear.toIso8601String());
  final yearList = yearAttendance as List;

  final weekCounts = List.generate(7, (i) => 0);
  final monthlyCounts = List.generate(12, (i) => 0);
  final monthCounts = List.generate(monthEnd, (i) => 0);
  for (final a in yearList) {
    final t = DateTime.parse(a['check_in_time'] as String);
    final day = t.day - 1;
    if (t.isAfter(weekStart) || t.isAtSameMomentAs(weekStart)) {
      if (t.weekday - 1 >= 0 && t.weekday - 1 < 7) weekCounts[t.weekday - 1]++;
    }
    if (t.month - 1 >= 0 && t.month - 1 < 12) monthlyCounts[t.month - 1]++;
    if (t.month == today.month && day >= 0 && day < monthEnd) monthCounts[day]++;
  }
  final totalWorkouts = monthCounts.reduce((a, b) => a + b);
  final activeDays = monthCounts.where((c) => c > 0).length;

  // ONE measurements query: per-month weight (latest measurement per month this year)
  final measurements = await client
      .from('body_measurements')
      .select('weight_kg, measured_at')
      .eq('member_id', userId)
      .gte('measured_at', yearStart.toIso8601String())
      .lt('measured_at', nextYear.toIso8601String())
      .order('measured_at', ascending: true);
  final monthlyWeights = List<double?>.generate(12, (i) => null);
  for (final m in measurements as List) {
    final t = DateTime.parse(m['measured_at'] as String);
    final w = (m['weight_kg'] as num?)?.toDouble();
    if (w != null && t.month - 1 >= 0 && t.month - 1 < 12) {
      monthlyWeights[t.month - 1] = w; // ascending order -> last write = latest
    }
  }

  // Keep existing: goals (1 row), trainer assignment (1 row + profile), membership (1 row), open session
  final goals = await client.from('goals')
      .select('title').eq('member_id', userId).eq('status', 'active').limit(1);
  final activeGoal = (goals as List).isNotEmpty ? goals[0]['title'] as String? : null;

  final assignment = await client.from('trainer_assignments')
      .select('trainer_id').eq('member_id', userId).eq('status', 'active').limit(1);
  Map<String, dynamic>? trainerProfile;
  if ((assignment as List).isNotEmpty) {
    final trainerResp = await client.from('profiles')
        .select('id, full_name, avatar_url').eq('id', assignment[0]['trainer_id'] as String).single();
    trainerProfile = trainerResp;
  }

  final membershipResp = await client.from('memberships')
      .select('plan_name, end_date, status').eq('member_id', userId).eq('status', 'active').limit(1);
  final membership = membershipResp.isNotEmpty ? membershipResp[0] : null;

  final openSessionResp = await client.from('attendance')
      .select('check_in_time, expires_at').eq('member_id', userId)
      .eq('check_in_date', today.toIso8601String().split('T').first)
      .isFilter('check_out_time', null).limit(1);
  final openSession = openSessionResp.isNotEmpty ? openSessionResp[0] : null;

  return {
    'profile': profile,
    'weekCounts': weekCounts,
    'maxWeek': weekCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100),
    'monthlyCounts': monthlyCounts,
    'maxMonth': monthlyCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100),
    'monthlyWeights': monthlyWeights,
    'totalWorkouts': totalWorkouts,
    'activeDays': activeDays,
    'activeGoal': activeGoal,
    'trainer': trainerProfile,
    'membership': membership,
    'openSession': openSession,
  };
});
```

**Note:** `latestMeasurement` (weight/height) is no longer needed (StatRow removed in Task 3) — delete its old fetch. `weekStart` comparison uses `isAfter` so Monday's own check-ins are included (today ∈ week). Keep `maxWeek`/`maxMonth` via the fixed `a > b ? a : b` reducers.

- [ ] **Step 2:** `flutter analyze` → clean.
- [ ] **Step 3: Commit** from repo root: `git add mobile/fitness_app/lib/features/member/home/pages/home_page.dart` && `git commit -m "feat(mobile): slim home data provider to yearly attendance and weight"`

---

## Task 3: Rebuild home body — new charts, remove dead sections

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/home/pages/home_page.dart`

- [ ] **Step 1: Rewrite `HomeContent.build` children** to exactly this order (keep `_GreetingRow`, `_MembershipCard`, `_TrainerCard` unchanged; delete the rest):

```dart
const monthShort = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
// in build():
final monthlyCounts = data['monthlyCounts'] as List<int>;
final monthlyWeights = data['monthlyWeights'] as List<double?>;

return ListView(
  padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
  physics: const ClampingScrollPhysics(),
  children: [
    const SizedBox(height: 14),
    _GreetingRow(...),                       // unchanged
    const SizedBox(height: 12),
    if (showMembershipCard)
      StaggeredFadeIn(index: 0, child: _MembershipCard(membership: membership, openSession: openSession)),
    if (showMembershipCard) const SizedBox(height: 8),
    StaggeredFadeIn(index: offset, child: _WeekChart(weekCounts: weekCounts, maxCount: maxCount)),
    const SizedBox(height: 8),
    StaggeredFadeIn(index: 1 + offset, child: _YearChart(
      monthlyCounts: monthlyCounts,
      maxMonth: maxMonth,
      totalWorkouts: totalWorkouts,
      yearLabel: '${DateTime.now().year}',
    )),
    const SizedBox(height: 8),
    StaggeredFadeIn(index: 2 + offset, child: _MonthSummary(totalWorkouts: totalWorkouts, activeDays: activeDays)),
    const SizedBox(height: 8),
    StaggeredFadeIn(index: 3 + offset, child: _GrowthChart(
      monthlyWeights: monthlyWeights,
    )),
    const SizedBox(height: 8),
    if (trainer != null) ...[
      StaggeredFadeIn(index: 4 + offset, child: _TrainerCard(trainer: trainer)),
      const SizedBox(height: 8),
    ],
    const SizedBox(height: 16),
  ],
);
```

Remove `_TodayProgress` + `_ProgressBarRow`, `_QuickLogRow` + `_QuickCard`, `_MoreRow` + `_MoreTile`, `_StatRow` (KEEP `_StatCard` — used by `_MonthSummary`), old `_MonthChart`. Check the `go_router` import — `_TrainerCard` still uses `context.go('/member/chat')` → keep import.

- [ ] **Step 2: Add `_YearChart`** — ClayCard(outlined, medium): header Row: left Column: `Text('This Month', ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary))` + `Text(yearLabel, fontSize 10, ClayTokens.clayDarkTextTertiary)`; right pill Container (padding h9 v4, `ClayTokens.clayPrimaryLight.withAlpha(25)` bg, radius 20, border `clayPrimaryLight.withAlpha(50)`): `Text('Total: $totalWorkouts', fontSize 10, w700, clayPrimaryLight)`. Body: `ClayAreaChart(values: monthlyCounts.map((c) => c.toDouble()).toList(), labels: monthShort, strokeColor: const Color(0xFF3B82F6))`. Sub-caption: `Text('Check-ins per month', fontSize 10, clayDarkTextTertiary)`. Import `../.../shared/widgets/clay_area_chart.dart` (path: `../../../shared/widgets/clay_area_chart.dart`).
- [ ] **Step 3: Add `_GrowthChart`** — same card shell: header left: `Text('Growth Over Time', titleMedium dark)` + `Text('Weight per month', fontSize 10, tertiary)`; right pill: latest weight `'${(monthlyWeights.whereType<double>().toList().lastOrNull ?? 0).toStringAsFixed(1)} kg'` when non-empty (pill hidden when empty). Body: `ClayAreaChart(values: monthlyWeights, labels: monthShort, strokeColor: ClayTokens.clayPrimaryLight, emptyMessage: 'No weight data yet')`.
- [ ] **Step 4:** `flutter analyze` → clean; `rg -n "member/measurements|member/calendar|member/progress" mobile/fitness_app/lib/features/member/home` → 0 hits (tiles gone).
- [ ] **Step 5: Commit** from repo root: `git add mobile/fitness_app/lib/features/member/home/pages/home_page.dart` && `git commit -m "feat(mobile): admin-style month and growth charts on member home"`

---

## Task 4: Verify end-to-end

- [ ] **Step 1:** `flutter analyze` from `C:\capshii\capshii\mobile\fitness_app` → 0 errors/warnings (13 pre-existing infos OK).
- [ ] **Step 2:** `flutter build web --release` from `C:\capshii\capshii\mobile\fitness_app` → succeeds.
- [ ] **Step 3:** Grep sanity: `rg -n "_TodayProgress|_QuickLogRow|_MoreRow|_StatRow|_MonthChart" mobile/fitness_app/lib/features/member/home/pages/home_page.dart` → only `_MonthSummary`/`_StatCard` remain (0 hits for removed ones). Trainer app untouched.
- [ ] **Step 4:** Commit any fixes.

---

## Self-Review

- **Spec coverage:** removals (calories/time, log workout/meal, measurements/chat/calendar tiles, stat row, old month chart) ✓ (Tasks 2-3); This Week first ✓; This Month admin Daily Check-ins style with Jan–Feb x-axis ✓ (Task 1+3); Growth over time per month = weight ✓ (Task 3); keeps membership + trainer + summary cards ✓; `_StatCard` retention noted ✓ (used by `_MonthSummary`); no dead routes referenced ✓.
- **Placeholders:** none — code blocks complete.
- **Consistency:** provider keys (`monthlyCounts`, `maxMonth`, `monthlyWeights`, `totalWorkouts`, `activeDays`, `yearLabel`) match between Task 2 return map and Task 3 usage; `ClayAreaChart` API (values/labels/strokeColor/height/emptyMessage) matches Task 1.
