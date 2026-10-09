# Glass Surfaces, Record Cross-Out & Manual Food Entry — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the trainer Record sheet overflow, put the trainer record screen, plan sheets, and login inputs on the shared glass system, cross out trainer-assigned tasks the member has logged, and add a Manual (non-FNRI) branch to the add-food wizard.

**Architecture:** One new shared widget (`GlassSheetShell` in `glass_card.dart`) gives every bottom sheet the same backdrop-blurred dark-violet glass shell; the two trainer plan sheets and the trainer record details sheet adopt it. Record details become scrollable (kills the 16px RenderFlex overflow) and fetch the member's `workout_logs`/`meal_logs` inside the plan window (RLS already allows trainers to read assigned members' logs) to cross out completed plan items. The wizard gains a `bool _manual` branch: step 3 chooses FNRI vs Manual and collects the food name; step 4 collects kcal/protein/carbs/fat per 100 g with the same grams scaling, so `_MacroPreview` and the save path are shared.

**Tech Stack:** Flutter (material + cupertino), Riverpod, Supabase (`supabase_flutter`), existing `GlassPanel`/`ClayTokens` design system. App root: `c:\capstsh\mobile\fitness_app`.

**Spec:** This plan (brainstorm summary in header; user approved flow: brainstorm → plan → execute, no re-approval loop).

## Global Constraints
- Verification after every task: `flutter analyze --no-pub` (from `c:\capstsh\mobile\fitness_app`) must report 0 issues; final task runs `flutter test` (14 existing tests stay green).
- `ClayTokens.clayPrimary` is non-const — never `const`-combine it.
- No DB migrations. Manual foods save to `meal_logs` exactly like FNRI foods.
- Dart 3 records are already used in the codebase; `({String text, bool done})` is safe.
- Match existing style: `Color(0xFF7C3AED)`, `Color(0xFF30D158)`, glass fills `Colors.white.withAlpha(n)`, radius 14–20.

## Review Focus
- Record sheet: future created ONCE before `showModalBottomSheet` (not inside `builder`) to avoid refetch loops.
- `_PlanDaySection` call sites pass done-aware `items` (meals match food names; exercises match workout names on the NAME portion only, before " — ").
- Wizard: `food!` only allowed in non-manual review branches (manual has `_selectedFood == null`).
- Login: floating label stays INSIDE the field (`top: 6` when floating) — no opaque patch on translucent fill.
- Glass shells keep drag-handle/notes banner/"See all" taps intact (only the outer container is re-parented).

## File Structure
- Modify `mobile/fitness_app/lib/features/shared/widgets/glass_card.dart` — add `GlassSheetShell`.
- Modify `mobile/fitness_app/lib/features/shared/widgets/trainer_plan_overlay.dart` — both sheet containers → `GlassSheetShell`.
- Modify `mobile/fitness_app/lib/features/trainer/set_plan/pages/record_screen.dart` — glass cards, glass + scrollable details sheet, completion fetch, cross-out `_PlanDaySection`.
- Modify `mobile/fitness_app/lib/features/auth/pages/login_page.dart` — field gap, glass inputs, label-inside-field, logo 1px gap + block higher.
- Modify `mobile/fitness_app/lib/features/member/meals/pages/add_food_wizard.dart` — manual mode (step 3 chooser + name, step 4 macro inputs, review/save branches).

---

## Task 1: `GlassSheetShell` shared widget

- [ ] **Step 1: Append the widget to `glass_card.dart`** (after `GlassPanel`): a top-rounded (20) `ClipRRect` → `BackdropFilter(blur 28)` → `Container` whose decoration is a vertical `LinearGradient` from `Color(0xB31E1B3A)` to `Color(0xD9120F26)`, `Border.all(Colors.white.withAlpha(30))`, and a `BoxShadow(Colors.black.withAlpha(90), blurRadius: 30, offset: Offset(0, -6))`. Public API: `const GlassSheetShell({super.key, required this.child, this.blur = 28})`. (`dart:ui` `ImageFilter` is already imported in that file.)

- [ ] **Step 2: Verify** — `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 3: Commit** — `git add lib/features/shared/widgets/glass_card.dart` + commit `feat: add GlassSheetShell shared bottom-sheet glass surface`


## Task 2: Trainer plan sheets → glass shell (`trainer_plan_overlay.dart`)

Both `TrainerPlanSheet` (~line 260) and `TrainerPlanFoodOverlay` (~line 668) contain the identical container:

```dart
Container(
  padding: padding,
  decoration: const BoxDecoration(
    color: ClayTokens.clayDarkSurface,
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  child: Column(/* ... */),
)
```

- [ ] **Step 1: Replace each occurrence** with (inner `Column` and `padding` variable stay exactly as-is, just re-parented):

```dart
GlassSheetShell(
  child: Padding(
    padding: padding,
    child: Column(/* ...unchanged... */),
  ),
)
```

(`glass_card.dart` is already imported in this file for `GlassPanel`.)
- [ ] **Step 2: Verify** — `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 3: Commit** — `git add lib/features/shared/widgets/trainer_plan_overlay.dart` + commit `feat: workout & food plan sheets use GlassSheetShell`

## Task 3: Trainer Record screen — glass, scrollable (overflow fix), completion cross-out

File: `record_screen.dart`.

- [ ] **Step 1: Add imports** after the existing shared-widget import:

```dart
import 'dart:ui';
import '../../../../features/shared/widgets/glass_card.dart';
```

- [ ] **Step 2: Add normalised-name + log fetch helpers** (top-level, after the provider):

```dart
String _normPlanName(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Loads the member's logged exercise/food names within the plan window so
/// the record sheet can cross out completed tasks. RLS already lets a
/// trainer read assigned members' workout_logs and meal_logs; any failure
/// degrades to "nothing crossed out" instead of breaking the sheet.
Future<(Set<String>, Set<String>)> _fetchCompletedNames(
  String memberId,
  String startDate,
  String endDate,
) async {
  try {
    final start = DateTime.parse(startDate).toUtc();
    final end = DateTime.parse(endDate)
        .add(const Duration(days: 1))
        .toUtc();
    final client = SupabaseClientService().client;
    final workouts = await client
        .from('workout_logs')
        .select('exercise_name')
        .eq('member_id', memberId)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String());
    final meals = await client
        .from('meal_logs')
        .select('food_name')
        .eq('member_id', memberId)
        .gte('meal_time', start.toIso8601String())
        .lt('meal_time', end.toIso8601String());
    final workoutNames = {
      for (final r in workouts as List)
        if (((r as Map)['exercise_name'] ?? '').toString().isNotEmpty)
          _normPlanName(r['exercise_name'].toString()),
    };
    final foodNames = {
      for (final r in meals as List)
        if (((r as Map)['food_name'] ?? '').toString().isNotEmpty)
          _normPlanName(r['food_name'].toString()),
    };
    return (workoutNames, foodNames);
  } catch (_) {
    return (<String>{}, <String>{});
  }
}
```

- [ ] **Step 3: Glass the record list cards** — replace the `GestureDetector(... child: Container(margin:, padding: all(16), decoration: BoxDecoration(color: ClayTokens.clayDarkSurfaceElevated, ...)))` wrapper with:

```dart
return GlassPanel(
  margin: const EdgeInsets.only(bottom: 12),
  borderRadius: BorderRadius.circular(16),
  child: Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        _showPlanDetails(context, record);
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          /* ...entire existing card content unchanged... */
        ),
      ),
    ),
  ),
);
```

- [ ] **Step 4: Rewrite `_showPlanDetails` shell** — before `showModalBottomSheet` add:

```dart
final completedFuture = memberId == null
    ? Future.value((<String>{}, <String>{}))
    : _fetchCompletedNames(memberId, startDate, endDate);
```

then replace the sheet (removing `backgroundColor:`/`shape:`; the existing `Column` children stay verbatim except the plan-list change in Step 5):

```dart
showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  builder: (ctx) {
    return GlassSheetShell(
      child: FutureBuilder<(Set<String>, Set<String>)>(
        future: completedFuture,
        builder: (context, snap) {
          final workoutNames = snap.data?.$1 ?? const <String>{};
          final foodNames = snap.data?.$2 ?? const <String>{};
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              32 + MediaQuery.of(ctx).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ /* ...existing children... */ ],
            ),
          );
        },
      ),
    );
  },
);
```

- [ ] **Step 5: Done-aware plan sections** — replace the `ConstrainedBox(maxHeight: 260, child: SingleChildScrollView(child: Column(...)))` block with a plain `Column`:

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    for (final dayEntry in foodPlan)
      _PlanDaySection(
        day: (dayEntry as Map<String, dynamic>)['day'],
        title: 'Meals',
        items: [
          for (final f in (dayEntry['foods'] as List<dynamic>? ?? const []))
            if (((f as Map)['name'] ?? '').toString().isNotEmpty)
              (
                text: ((f as Map)['name'] ?? '').toString(),
                done: foodNames.contains(
                    _normPlanName(((f as Map)['name'] ?? '').toString())),
              ),
        ],
      ),
    for (final dayEntry in exercisePlan)
      _PlanDaySection(
        day: (dayEntry as Map<String, dynamic>)['day'],
        title: 'Exercises',
        items: [
          for (final e in (dayEntry['exercises'] as List<dynamic>? ?? const []))
            if (((e as Map)['name'] ?? '').toString().isNotEmpty)
              _exerciseItem(e as Map, workoutNames),
        ],
      ),
  ],
),
```

with the helper (top-level):

```dart
({String text, bool done}) _exerciseItem(Map m, Set<String> workoutNames) {
  final name = (m['name'] ?? '').toString();
  final sets = (m['sets'] ?? '').toString();
  final reps = (m['reps'] ?? '').toString();
  final weight = (m['weight'] ?? '').toString();
  final detail = [
    if (sets.isNotEmpty) '$sets sets',
    if (reps.isNotEmpty) '$reps reps',
    if (weight.isNotEmpty) '${weight}kg',
  ].join(' · ');
  return (
    text: detail.isEmpty ? name : '$name — $detail',
    done: workoutNames.contains(_normPlanName(name)),
  );
}
```

- [ ] **Step 6: Replace `_PlanDaySection`** with the done-aware version (fields: `dynamic day`, `String title`, `List<({String text, bool done})> items`). Build: skip when empty; `doneCount = items.where((i) => i.done).length`; Container `color: Colors.white.withAlpha(10)`, radius 10, padding 12; header `Row(spaceBetween)` with the existing `'Day $day · $title'` purple text plus (when `doneCount > 0`) a green `'$doneCount/${items.length} done'` (fontSize 10.5, `Color(0xFF30D158)`); then per item a `Row` with `Icon(item.done ? Icons.check_circle : Icons.radio_button_unchecked, size: 13, color: done ? Color(0xFF30D158) : Color(0xFF8E8E93))`, `SizedBox(6)`, and `Expanded(Text(item.text, decoration: done ? lineThrough : none, color: done ? Color(0xFF8E8E93) : Color(0xFFECECFC), fontSize: 13))`.

- [ ] **Step 7: Verify** — `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 8: Commit** — `git add lib/features/trainer/set_plan/pages/record_screen.dart` + commit `feat: record screen glass + scrollable sheet + cross out logged tasks`


## Task 4: Login page — field gap, glass inputs, logo 1px, block higher

File: `login_page.dart`.

- [ ] **Step 1: Move block higher + logo 1px gap** — in `build`: top spacer `SizedBox(height: 48)` → `SizedBox(height: 40)`; bottom spacer `SizedBox(height: 32)` → `SizedBox(height: 96)` (block rises ~36px under `MainAxisAlignment.center`). Wrap the logo `Stack` in:

```dart
Transform.translate(
  // The 132px glow circle carries 18px of transparent padding below the
  // 96px image; translating down 18px puts the image bottom 1px above
  // the card without changing the layout height.
  offset: const Offset(0, 18),
  child: Stack(/* ...unchanged... */),
)
```

and change the `SizedBox(height: 16)` between logo and card → `SizedBox(height: 1)`.

- [ ] **Step 2: Real gap between the fields** — replace the hairline (and its stale comment):

```dart
// 1px card gap: the two inputs sit as a stacked pair, joined by a hairline.
const SizedBox(height: 1),
```

with:

```dart
// Breathing room between the two glass inputs.
const SizedBox(height: 12),
```

- [ ] **Step 3: Glass the inputs** — in `_FloatingLabelInputState.build`, `AnimatedContainer` decoration becomes:

```dart
decoration: BoxDecoration(
  // Glass fill: translucent white over the card's backdrop blur so the
  // glow shows through (matches the wizard's glass inputs).
  color: Colors.white.withValues(alpha: 0.07),
  borderRadius: BorderRadius.circular(14),
  border: Border.all(
    color: focused
        // Purple focus ring — the login card's accent colour.
        ? const Color(0xFF7C3AED).withValues(alpha: 0.75)
        : Colors.white.withValues(alpha: 0.18),
    width: focused ? 1.4 : 1,
  ),
),
```

- [ ] **Step 4: Label floats inside the field** — same state: `AnimatedPositioned` `top: floating ? -9 : 14` → `top: floating ? 6 : 14`; on the label patch `Container` remove `color: CupertinoAppColors.cardElevated` (translucent fill cannot be masked by an opaque patch; floating inside the field needs no notch). Keep its horizontal-4 padding when floating.
- [ ] **Step 5: Verify** — `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 6: Commit** — `git add lib/features/auth/pages/login_page.dart` + commit `feat: login glass inputs, real field gap, logo 1px above card, block higher`

## Task 5: Add-food wizard — FNRI vs Manual

File: `add_food_wizard.dart`.

- [ ] **Step 1: State + dispose** — in `_AddFoodWizardState` add:

```dart
bool _manual = false;
final _manualNameController = TextEditingController();
final _manualKcalController = TextEditingController();
final _manualProteinController = TextEditingController();
final _manualCarbsController = TextEditingController();
final _manualFatController = TextEditingController();
```

dispose them alongside the existing controllers.

- [ ] **Step 2: Base-value getters** — replace the calc block:

```dart
// Base values per 100 g: the FNRI row, or what the member typed in manual
// mode. Grams scaling (and the auto-calculated card) is shared.
double get _baseKcal => _manual
    ? (double.tryParse(_manualKcalController.text.trim()) ?? 0)
    : (_selectedFood?.caloriesKcal ?? 0);
double get _baseProtein => _manual
    ? (double.tryParse(_manualProteinController.text.trim()) ?? 0)
    : (_selectedFood?.proteinG ?? 0);
double get _baseCarbs => _manual
    ? (double.tryParse(_manualCarbsController.text.trim()) ?? 0)
    : (_selectedFood?.carbsG ?? 0);
double get _baseFat => _manual
    ? (double.tryParse(_manualFatController.text.trim()) ?? 0)
    : (_selectedFood?.fatG ?? 0);

double get _calories => _baseKcal * _factor;
double get _protein => _baseProtein * _factor;
double get _carbs => _baseCarbs * _factor;
double get _fat => _baseFat * _factor;

bool get _manualMacroInputsValid =>
    _manualKcalController.text.trim().isNotEmpty &&
    _manualProteinController.text.trim().isNotEmpty &&
    _manualCarbsController.text.trim().isNotEmpty &&
    _manualFatController.text.trim().isNotEmpty &&
    double.tryParse(_manualKcalController.text.trim()) != null &&
    double.tryParse(_manualProteinController.text.trim()) != null &&
    double.tryParse(_manualCarbsController.text.trim()) != null &&
    double.tryParse(_manualFatController.text.trim()) != null;
```

- [ ] **Step 3: `_canContinue` branches** — search step: `return _manual ? _manualNameController.text.trim().isNotEmpty : _selectedFood != null;` quantity step: `if (_grams <= 0) return false; return !_manual || _manualMacroInputsValid;`
- [ ] **Step 4: `_save` manual branch** — guard becomes:

```dart
final food = _selectedFood;
final mealType = _mealType;
final foodName =
    _manual ? _manualNameController.text.trim() : food?.foodName;
if (foodName == null || foodName.isEmpty || mealType == null || _grams <= 0) {
  return;
}
```

and in the insert map `'food_name': food.foodName,` → `'food_name': foodName,`.


- [ ] **Step 5: Step 3 chooser + name field** — prepend a source row to `_searchStep` and branch the body:

```dart
Widget _searchStep() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _StepHeading(
        title: _manual ? 'Enter food details' : 'Search & select food',
        subtitle: _manual
            ? 'Type the food name — you will enter its nutrition on the next step.'
            : 'Search the DOST-FNRI Philippine Food Composition Table '
                '(1,542 foods, with Filipino names).',
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(
            child: _SourceTile(
              label: 'FNRI table',
              icon: CupertinoIcons.search,
              selected: !_manual,
              onTap: () => setState(() => _manual = false),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SourceTile(
              label: 'Manual',
              icon: CupertinoIcons.pencil,
              selected: _manual,
              onTap: () => setState(() => _manual = true),
            ),
          ),
        ],
      ),
      const SizedBox(height: 14),
      if (!_manual) ...[
        TextField(/* ...existing search field, unchanged... */),
        const SizedBox(height: 12),
        if (_searching) /* ...existing... */,
        if (_searchError != null) /* ...existing... */,
        if (_searchController.text.trim().length >= 2 &&
            !_searching &&
            _results.isEmpty) /* ...existing empty-state text... */,
        const SizedBox(height: 8),
        ..._results.map(/* ...existing tiles... */),
      ] else ...[
        TextField(
          controller: _manualNameController,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: Color(0xFFFFFFFF), fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: _glassFill,
            hintText: 'e.g. Lumpia, homemade pancit',
            hintStyle: const TextStyle(color: Color(0xFF7070A0), fontSize: 14),
            prefixIcon: const Icon(
              CupertinoIcons.fork_knife,
              size: 18,
              color: Color(0xFFB4B4D0),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _glassBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _glassBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Color(0xFF7C3AED), width: 1.6),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'You will enter kcal, protein, carbs and fat on the next step.',
          style: TextStyle(color: Color(0xFF7070A0), fontSize: 12, height: 1.4),
        ),
      ],
    ],
  );
}
```

- [ ] **Step 6: `_SourceTile` widget** — compact selectable tile matching `_FoodResultTile` styling: GestureDetector → Container (padding v12/h12, fill `selected ? Color(0xFF7C3AED).withAlpha(26) : _glassFill`, radius 14, border selected purple width 1.5 else `_glassBorder`), Row centered: `Icon(icon, 16, selected ? Color(0xFFD6A5FF) : Color(0xFFB4B4D0))`, `SizedBox(6)`, `Text(label, fontSize 13, w700, selected ? Color(0xFFECECFC) : Color(0xFFB4B4D0))`.


- [ ] **Step 7: Step 4 manual branch** — in `_quantityStep`: guard becomes `if (!_manual && food == null) return const SizedBox.shrink();`; heading subtitle conditional (`_manual ? 'Enter the nutrition per 100 g and how much you ate — the totals update automatically.' : 'FNRI values are per 100 g. Enter how much you ate and the nutrition updates automatically.'` — note `_StepHeading` must be constructed non-const here); card swap:

```dart
if (_manual)
  _ManualNutritionCard(
    name: _manualNameController.text.trim(),
    kcalController: _manualKcalController,
    proteinController: _manualProteinController,
    carbsController: _manualCarbsController,
    fatController: _manualFatController,
    onChanged: () => setState(() {}),
  )
else
  _SelectedFoodCard(food: food),
```

Everything below the card (grams label, grams field, chips, `_MacroPreview`) unchanged.

- [ ] **Step 8: Manual card widgets** — `_ManualNutritionCard`: same `_glassDecoration(borderRadius: 18)` container as `_SelectedFoodCard`; shows the food name (w700, `Color(0xFFECECFC)`, 15), `'Nutrition per 100 g (manually entered)'` (`Color(0xFFB4B4D0)`, 11), then two Rows of two `_ManualMacroField`s (kcal `0xFF7C3AED`, protein g `0xFF0A84FF` / carbs g `0xFFFF9500`, fat g `0xFF30D158`, 8px gaps). `_ManualMacroField`: Stateless; label (10, `Color(0xFF7070A0)`) + TextField (numberWithOptions decimal, `onChanged: (_) => onChanged()`, centered, style = color w800 15, fill `_glassFill`, radius 12, border `_glassBorder` / focus purple 1.5, hintText `'0'`).

- [ ] **Step 9: Review step branches** — in `_reviewStep`: `final food = _selectedFood;` then `final foodName = _manual ? _manualNameController.text.trim() : food!.foodName;`. Food row: `value: foodName`, `subtitle: _manual ? 'Manually entered' : (food!.aliases.isNotEmpty ? 'aka ${food.aliases.join(', ')}' : food.category)`. Quantity row subtitle: `_manual ? '${_baseKcal.toStringAsFixed(0)} kcal per 100 g · Manual entry' : '${food!.caloriesKcal.toStringAsFixed(0)} kcal per 100 g · ${food.source.isEmpty ? 'FNRI' : food.source}'`.

- [ ] **Step 10: Verify** — `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 11: Commit** — `git add lib/features/member/meals/pages/add_food_wizard.dart` + commit `feat: add-food wizard manual mode (FNRI vs manual, per-100g macro inputs)`

## Task 6: Full verification

- [ ] **Step 1:** `flutter analyze --no-pub` → 0 issues.
- [ ] **Step 2:** `flutter test` → 14/14 pass.
- [ ] **Step 3:** Report summary + visual-check list to the user (hot restart required).

