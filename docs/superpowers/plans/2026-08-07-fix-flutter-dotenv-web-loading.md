# Fix Flutter Web `.env` Loading Failure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Flutter Web startup crash caused by `flutter_dotenv` failing to load `assets/.env` with HTTP 500 / `FileNotFoundError`, and ensure Supabase credentials are available at runtime.

**Architecture:** Keep `.env` inside the app's declared asset tree so Flutter Web can serve it reliably, and load it with an explicit relative path from `main.dart`. This preserves the existing mobile behavior while fixing web without introducing platform branches.

**Tech Stack:** Flutter, `flutter_dotenv`, `flutter_riverpod`, Supabase Flutter client

---

### Task 1: Move `.env` into the assets folder

**Files:**
- Create: `mobile/fitness_app/assets/.env`
- Modify: none

- [ ] **Step 1: Create `assets/.env` with placeholder values**

Create `mobile/fitness_app/assets/.env` with:
```
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
```

- [ ] **Step 2: Verify the new file exists**

Run:
```powershell
Test-Path "C:\capstsh\mobile\fitness_app\assets\.env"
```
Expected: `True`

- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/assets/.env
git commit -m "chore: add assets/.env placeholder for flutter_dotenv"
```

---

### Task 2: Update asset declaration in `pubspec.yaml`

**Files:**
- Modify: `mobile/fitness_app/pubspec.yaml`

- [ ] **Step 1: Update the `flutter.assets` list**

Replace the current asset entries:
```yaml
flutter:
  uses-material-design: true
  assets:
    - .env
    - assets/
```

With:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/.env
    - assets/
```

- [ ] **Step 2: Verify YAML parses and assets are declared**

Run:
```powershell
cd C:\capstsh\mobile\fitness_app; flutter pub get
```
Expected: dependencies resolve, no YAML error.

- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/pubspec.yaml
git commit -m "fix: declare assets/.env instead of root .env for flutter_dotenv web compatibility"
```

---

### Task 3: Update `main.dart` to load `.env` from the asset path explicitly

**Files:**
- Modify: `mobile/fitness_app/lib/main.dart`

- [ ] **Step 1: Change `dotenv.load()` to use the asset path**

Update the load call from:
```dart
await dotenv.load();
```

To:
```dart
await dotenv.load(fileName: 'assets/.env');
```

- [ ] **Step 2: Verify the file compiles**

Run:
```powershell
cd C:\capstsh\mobile\fitness_app; flutter analyze
```
Expected: analysis succeeds, no errors in `main.dart`.

- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/lib/main.dart
git commit -m "fix: load flutter_dotenv from assets/.env explicitly"
```

---

### Task 4: Replace placeholder values with real Supabase credentials

**Files:**
- Modify: `mobile/fitness_app/assets/.env`

- [ ] **Step 1: Update `assets/.env` with actual values**

Replace placeholders with real values:
```
SUPABASE_URL=https://<your-project>.supabase.co
SUPABASE_ANON_KEY=<your-anon-key>
```

- [ ] **Step 2: Confirm secrets are not committed in plaintext in unintended locations**

Run:
```powershell
cd C:\capstsh; git ls-files | Select-String "fitness_app/assets/.env"
```
Expected: `assets/.env` is tracked only if you intentionally want it tracked; if not, add it to `.gitignore` separately.

- [ ] **Step 3: Commit**

```bash
git add mobile/fitness_app/assets/.env
git commit -m "chore: add real Supabase credentials to assets/.env"
```

---

### Task 5: Verify the fix on Flutter Web

**Files:**
- None

- [ ] **Step 1: Run the app on Chrome**

Run:
```powershell
cd C:\capstsh\mobile\fitness_app; flutter run -d chrome
```
Expected: app launches without `FileNotFoundError` or HTTP 500 for `assets/.env`.

- [ ] **Step 2: Confirm Supabase initializes**

In app behavior or logs, confirm no missing-key crash occurs and the app reaches the home screen or router.

- [ ] **Step 3: Commit if any small follow-up config changes are needed**

Only if new config issues surface during verification.
