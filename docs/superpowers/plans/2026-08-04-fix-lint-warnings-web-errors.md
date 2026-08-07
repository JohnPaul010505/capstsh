# Fix Lint Warnings + Web Runtime Errors

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix all Dart analyzer `info`-level warnings (17 total across 8 files) and resolve the web runtime `.env`/`FontManifest.json` 404 errors.

**Architecture:** Two categories — (1) code style fixes (braces, const, naming, etc.) that are pure mechanical replacements, (2) web asset configuration for `.env` file loading.

**Tech Stack:** Flutter, Dart analyzer.

**Branch:** `main` (current).

**Verification baseline:** `flutter analyze --no-pub` → 0 issues; `flutter build web --release` → succeeds.

---

## Task 1: Fix `curly_braces_in_flow_control_structures` in responsive.dart

9 occurrences where `if`/`else if` statements lack curly braces.

**File:** `mobile/fitness_app/lib/app/responsive.dart`

**Lines 235-237:**
```dart
// Before:
if (rc.isDesktop && desktop != null) size = desktop!;
else if (rc.isTablet && tablet != null) size = tablet!;
else size = phone ?? ClayTokens.md;

// After:
if (rc.isDesktop && desktop != null) {
  size = desktop!;
} else if (rc.isTablet && tablet != null) {
  size = tablet!;
} else {
  size = phone ?? ClayTokens.md;
}
```

**Lines 262-264:**
```dart
// Before:
if (rc.isDesktop && desktop != null) padding = desktop!;
else if (rc.isTablet && tablet != null) padding = tablet!;
else padding = phone ?? EdgeInsets.symmetric(horizontal: rc.pageHorizontalPadding, vertical: ClayTokens.md);

// After:
if (rc.isDesktop && desktop != null) {
  padding = desktop!;
} else if (rc.isTablet && tablet != null) {
  padding = tablet!;
} else {
  padding = phone ?? EdgeInsets.symmetric(horizontal: rc.pageHorizontalPadding, vertical: ClayTokens.md);
}
```

**Lines 333-335:**
```dart
// Before:
if (rc.isDesktop) columns = desktopColumns ?? 4;
else if (rc.isTablet) columns = tabletColumns ?? 3;
else columns = phoneColumns ?? 2;

// After:
if (rc.isDesktop) {
  columns = desktopColumns ?? 4;
} else if (rc.isTablet) {
  columns = tabletColumns ?? 3;
} else {
  columns = phoneColumns ?? 2;
}
```

- [ ] **Step 1:** Apply all 3 brace-wrapping changes in `responsive.dart`
- [ ] **Step 2:** `dart analyze responsive.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): add curly braces to if/else in responsive.dart`

---

## Task 2: Fix `unnecessary_const` in glow_card.dart

**File:** `mobile/fitness_app/lib/features/member/calendar/widgets/glow_card.dart`

**Line 54:**
```dart
// Before:
const _RadialGlow(const Color(0xFF5E3AEE), Alignment(-0.9, -0.9)),

// After:
const _RadialGlow(Color(0xFF5E3AEE), Alignment(-0.9, -0.9)),
```

Remove the inner `const` — the outer `const` already propagates.

- [ ] **Step 1:** Remove inner `const` on line 54
- [ ] **Step 2:** `dart analyze glow_card.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): remove unnecessary const in glow_card.dart`

---

## Task 3: Fix `prefer_conditional_assignment` in chat_page.dart

**File:** `mobile/fitness_app/lib/features/member/chat/pages/chat_page.dart`

**Lines 132-134:**
```dart
// Before:
if (_roomId == null) {
  _roomId = await _createRoom();
}

// After:
_roomId ??= await _createRoom();
```

- [ ] **Step 1:** Replace the `if` block with `??=`
- [ ] **Step 2:** `dart analyze chat_page.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): use ??= in chat_page.dart`

---

## Task 4: Fix `unnecessary_library_name` in met_exercise_catalog.dart

**File:** `mobile/fitness_app/lib/features/member/workout/data/met_exercise_catalog.dart`

**Line 6:**
```dart
// Before:
library met_exercise_catalog;

// After:
// (delete the line entirely)
```

- [ ] **Step 1:** Delete line 6 (`library met_exercise_catalog;`)
- [ ] **Step 2:** `dart analyze met_exercise_catalog.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): remove unnecessary library name`

---

## Task 5: Fix `prefer_initializing_formals` in workout_session_provider.dart

**File:** `mobile/fitness_app/lib/features/member/workout/providers/workout_session_provider.dart`

**Line 53:**
```dart
// Before:
}) : _latestCalories = latestCalories;

// After:
}) ;
```
Wait — the `latestCalories` is a named param that gets assigned to `_latestCalories`. We can use `this._latestCalories` in the constructor param list. Let me re-read the constructor.

Actually, looking at lines 40-53:
```dart
const WorkoutSessionState({
  this.exercises = const [],
  ...
  int? latestCalories,
}) : _latestCalories = latestCalories;
```

The fix is to change the constructor param to `int? latestCalories` → `this._latestCalories` but since `_latestCalories` is private, we can't use `this.` on it. The `prefer_initializing_formals` lint fires when a constructor parameter has the same name as a field. Here the param is `latestCalories` and the field is `_latestCalories` — different names, so this is actually a false positive or a different issue.

Let me re-check: the lint says "Use an initializing formal to assign a parameter to a field." But the field is `_latestCalories` (private) and the param is `latestCalories` (public). We can't use `this._latestCalories` because private fields can't be initializing formals in some Dart versions.

Actually, in modern Dart, you CAN use `this._field` in constructor params. Let me verify:

```dart
const WorkoutSessionState({
  ...
  this._latestCalories,
}) : super();
```

But the current code has `int? latestCalories` as a separate param that's assigned to `_latestCalories` in the initializer list. If we change it to `this._latestCalories`, the constructor signature changes (the param name becomes `_latestCalories` with a leading underscore, which is unusual for public API).

The safest fix is to keep the current pattern but suppress the lint with `// ignore: prefer_initializing_formals` since this is a private field with a different name. Or we can just leave it as-is since it's an `info` level warning.

Actually, let me re-read the error message: "Use an initializing formal to assign a parameter to a field. Try using an initialing formal ('this._latestCalories') to initialize the field."

So the fix IS to use `this._latestCalories`:
```dart
const WorkoutSessionState({
  ...
  this._latestCalories,
}) : super();
```

But this changes the public API — callers would need to use `_latestCalories` as the param name. Since `_latestCalories` is private, this doesn't work for external callers.

The best approach is to suppress this specific lint for this line:
```dart
// ignore: prefer_initializing_formals
}) : _latestCalories = latestCalories;
```

Or just leave it as an info-level warning. Let me check if there are any callers that use this constructor.

Actually, looking more carefully, the `WorkoutSessionState` constructor is only used internally within the provider. So changing the param name to `_latestCalories` would be fine. But it's unusual to have a private param name in a constructor.

Let me just suppress the lint for this one line since it's the cleanest approach.

- [ ] **Step 1:** Add `// ignore: prefer_initializing_formals` above line 53, or leave as-is (info-level, acceptable)
- [ ] **Step 2:** `dart analyze workout_session_provider.dart` → 0 issues (if suppressed)
- [ ] **Step 3:** Commit `style(mobile): suppress prefer_initializing_formals in workout_session_provider.dart`

---

## Task 6: Fix `curly_braces_in_flow_control_structures` in clay_chip.dart

**File:** `mobile/fitness_app/lib/features/shared/widgets/clay/clay_chip.dart`

**Lines 277-278:**
```dart
// Before:
if (selected) _selected.add(option);
else _selected.remove(option);

// After:
if (selected) {
  _selected.add(option);
} else {
  _selected.remove(option);
}
```

- [ ] **Step 1:** Add braces to the if/else block
- [ ] **Step 2:** `dart analyze clay_chip.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): add curly braces in clay_chip.dart`

---

## Task 7: Fix `dangling_library_doc_comments` in clay_tokens.dart

**File:** `mobile/fitness_app/lib/features/shared/widgets/clay/clay_tokens.dart`

**Line 1:**
```dart
// Before:
/// Re-export all Claymorphism design tokens and widgets for easy importing

// After:
/// Re-export all Claymorphism design tokens and widgets for easy importing
library;
```

Or simply remove the doc comment since it's a barrel file:
```dart
// Before:
/// Re-export all Claymorphism design tokens and widgets for easy importing

// After:
// (delete the doc comment line)
```

The cleanest fix is to add `library;` after the doc comment.

- [ ] **Step 1:** Add `library;` after the doc comment on line 1
- [ ] **Step 2:** `dart analyze clay_tokens.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): add library directive to clay_tokens.dart`

---

## Task 8: Fix `no_leading_underscores_for_local_identifiers` in nav_icons.dart

**File:** `mobile/fitness_app/lib/features/shared/widgets/nav_icons.dart`

**Line 223:**
```dart
// Before:
void _person(double cx) {

// After:
void person(double cx) {
```

Rename the local function from `_person` to `person`. Search for all usages of `_person` within the same scope and update them.

- [ ] **Step 1:** Rename `_person` to `person` on line 223 and any call sites
- [ ] **Step 2:** `dart analyze nav_icons.dart` → 0 issues
- [ ] **Step 3:** Commit `style(mobile): rename _person to person in nav_icons.dart`

---

## Task 9: Fix `.env` loading on Flutter web

The `.env` file is declared as a Flutter asset in `pubspec.yaml` but `flutter_dotenv` on web tries to fetch it via HTTP from `assets/.env`, which returns 404. The fix is to use `FlutterDotEnv`'s web-compatible loading.

**File:** `mobile/fitness_app/lib/main.dart`

**Current (line 10):**
```dart
await dotenv.load();
```

**Fix:**
```dart
await dotenv.load(fileName: '.env');
```

Actually, the issue is that on web, `flutter_dotenv` tries to load from the asset bundle which serves files from `build/web/assets/`. The `.env` file needs to be in the `web/` directory or loaded differently.

The standard fix for `flutter_dotenv` on web is:
1. Copy `.env` to `web/.env` (so it's served as a static file)
2. Or use `dotenv.load()` with a fallback

But the simplest fix is to ensure the `.env` file is in the `web/` directory:
```bash
cp mobile/fitness_app/.env mobile/fitness_app/web/.env
```

And update `pubspec.yaml` to not include `.env` in flutter assets (since web loads it differently).

Actually, the better approach is to check if the app has a `web/` directory and handle it.

- [ ] **Step 1:** Check if `web/` directory exists, copy `.env` to `web/.env`
- [ ] **Step 2:** Verify `.env` is accessible at `http://localhost:PORT/.env`
- [ ] **Step 3:** Commit `fix(mobile): copy .env to web/ directory for Flutter web loading`

---

## Task 10: End-to-end verification

- [ ] **Step 1:** `flutter analyze --no-pub` from `mobile/fitness_app/` → 0 issues
- [ ] **Step 2:** `flutter build web --release` → succeeds
- [ ] **Step 3 (manual):** Run `flutter run -d chrome` → no `.env` 404 errors in console
