# Food Intake Flow Rebuild + AI Recommendation Enablement

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal (user report):** "my biggest concern is the members foodintake screen the flow is not yet fix — make sure the flow is fixed and the AI recommendation works." Plus the agreed gap list (specs: `docs/superpowers/specs/2026-09-22-food-intake-and-ai.md`), excluding AI inactive-member detection and per-member QR codes.

**Root causes found (all verified in code):**
1. `API_BASE_URL` missing from both mobile `.env` files → falls back to `http://localhost:3001`, while `ai-service/main.py` binds **8000** (admin Vite proxy also targets 3001) → every AI call fails.
2. `identify_food.py` uses model `gemini-3.6-flash` (invalid for `google-generativeai==0.8.4`) → guaranteed 502.
3. `identify_food.py` fetches the photo over plain `httpx` from the `proofs` public URL, but bucket RLS (00014) only grants `authenticated` → bucket must be public or the call 400s at the image fetch.
4. `food.py` reads `profiles.age`/`profiles.fitness_goal` (columns don't exist) and orders `meal_logs` by `logged_at` (column is `meal_time`) → recommendation loses all member context.
5. Gemini fallbacks are Western dishes; `nutrition_foods` is seeded with Filipino dishes.
6. Mobile never writes `food_identification_logs` / `food_recommendations`; save errors are swallowed; meal type defaults silently; unmatched AI candidates leave blank macros with no hint.

**Fix strategy:** Phase 0 unblock config → Phase 1 flow rebuild (dead-end free) → Phase 2 recommendation end-to-end → Phase 3 workstreams W1–W4.

**Tech Stack:** Flutter/Dart (Riverpod, Supabase Dart client, fl_chart), FastAPI (`ai-service`), Supabase (Postgres RLS, Storage), React admin (Phase 3).

**Branch:** `main` (repo convention — all recent work commits directly to main).

**Verification baseline:** `flutter analyze --no-pub` → 0 new issues; `flutter build web --release` → succeeds; `python -m py_compile` on every touched `ai-service` file.

---

## Task 1: Phase 0 — make the AI service reachable

**Files:**
- Modify: `ai-service/main.py`
- Modify: `ai-service/services/gemini.py`
- Modify: `ai-service/routers/identify_food.py`
- Create: `ai-service/.env.example`
- Modify: `mobile/fitness_app/.env`, `mobile/fitness_app/assets/.env`

- [x] **Step 1:** `main.py` — `PORT = int(os.getenv("PORT", "3001"))`, `uvicorn.run(..., port=PORT)`.
- [x] **Step 2:** `main.py` — `CORS_ORIGINS` env (comma-separated, default `*`), `allow_credentials=False`.
- [x] **Step 3:** `GEMINI_MODEL` env (default `gemini-2.0-flash`) in `gemini.py` and `identify_food.py`.
- [x] **Step 4:** `ai-service/.env.example` with `GEMINI_API_KEY`, `GEMINI_MODEL`, `PORT`, `CORS_ORIGINS`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`.
- [x] **Step 5:** add `API_BASE_URL=http://localhost:3001` to both mobile env files.
- [x] **Step 6:** verify the `proofs` bucket is publicly readable — **confirmed via the storage API: `bucket: proofs | public=True`**.
- [x] **Step 7:** `python -m py_compile` on all touched service files → exit 0.

## Task 2: Phase 1 — FOOD INTAKE flow rebuild

**Files:**
- Modify: `mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart`

- [x] **Step 1:** meal type required in ALL modes — dropdown gets a "Select meal type…" sentinel (`_mealType` starts empty), Save disabled until chosen; `_mealTypeSelected` set on change for manual mode too.
- [x] **Step 2:** track `_memberEdited` (photo mode): true when the member picks a candidate chip other than the first, or overrides via nutrition search.
- [x] **Step 3:** `_save()` — no more `catch (_) {}`; add `_saveError` state, show it inline with a Retry button; keep the form open on failure.
- [x] **Step 4:** on photo-mode save, insert into `food_identification_logs` (`member_id`, `photo_url`, `ai_candidates` = `_candidates`, `selected_food`, `member_edited` = `_memberEdited`).
- [x] **Step 5:** photo mode + unmatched candidate → show the "not matched" hint + the nutrition search field (same `_buildSearchField()` as manual) so the member can fix macros; save stays possible.
- [x] **Step 6:** progress mapping upload 0.2 → identify 0.6 → nutrition 0.85 → done 1.0 (service is single-shot; keep the 30s timeout).

## Task 3: Phase 2 — AI recommendation end-to-end (next run)

**Files:**
- Modify: `ai-service/routers/food.py`
- Create: `mobile/shared/lib/services/meal_recommendation_service.dart`
- Modify: `mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart` (suggestions card + tap-to-prefill)
- Create: `supabase/migrations/0022_food_recommendation_macros.sql` (optional macros)

- [ ] **Step 1:** `food.py` — order `meal_logs` by `meal_time` (not `logged_at`); keep limit 20.
- [ ] **Step 2:** `food.py` — member context from `goals` (title/target/unit/status) + age computed from `profiles.date_of_birth`; drop the non-existent `age`/`fitness_goal` columns.
- [ ] **Step 3:** `food.py` — replace Western `FALLBACKS` with Filipino dishes aligned with `nutrition_foods` (Adobo, Sinigang, Sisig, Tinola, Longganisa…).
- [ ] **Step 4:** `meal_recommendation_service.dart` — POST `/api/ai/food-recommendations` `{member_id, meal_type}` → list; persist each to `food_recommendations` (`member_id`, `meal_type`, `food_name`, `portion_size`, `reason`).
- [ ] **Step 5:** meal page — after a successful save, fetch + render the "AI Suggestions" card (3 items: name, portion, macros, reason) with a tap-to-prefill action; loading/error states non-blocking.
- [ ] **Step 6:** verify one row lands in `food_recommendations` after a save.

## Task 4: Phase 3 — remaining workstreams (one change each, unchecked)

- [x] **W1a:** member progress prediction — DONE: `0022_predictions_member_rls.sql` (members read their own, trainers read assigned members' — writes stay service-role only), `ai-service/routers/predictions.py` now persists each forecast to `predictions` (Table 25), new `features/shared/services/prediction_service.dart` + `api_config.dart`, and `_PredictionCard` ("AI PROGRESS FORECAST": current → predicted, trend, confidence %) on member home with a friendly "not enough data" state for the API's 404.
- [x] **W1b:** trainer retention risk — DONE: `trainerDashboardProvider` now fetches `/api/ai/predictions` per assigned member (parallel, capped at 30, failures drop out silently) and the dashboard renders an **"AT-RISK MEMBERS"** section with high/medium/low chips sorted by risk score. *(The unused `Prediction` model gets its first consumer via `PredictionResult`.)*
- [ ] **W1c:** goal suggestion — `/api/ai/goal-adjustments` prefill in `create_goal_card` and `create_plan_screen`.
- [ ] **W2a:** migration `0023_trainer_feedback_rating.sql` — add `rating int check (rating between 1 and 5)` to `trainer_feedback` + RLS recheck.
- [ ] **W2b:** trainer "Give feedback" action in `member_progress_page.dart` wiring the existing `FeedbackService.submitFeedback` (today dead code).
- [ ] **W2c:** member `feedback_page.dart` — read-only feedback + 1–5 star rating control; remove the inverted member insert.
- [ ] **W3a:** member registration/enrollment screen writing `enrollments` (status `pending`), reusing the unused `Enrollment` model.
- [ ] **W3b:** trainer "Record measurement" form → `MeasurementService.createMeasurement`.
- [ ] **W3c:** trainer profile edit (update path for `profiles`).
- [ ] **W3d:** retire `meal_records`/`MealService` (Table 16) or migrate it — single meal path.
- [ ] **W4a:** admin — register `/predictions` + `/logs` routes in `App.tsx`, add sidebar links, surface `useGeneratePredictions`.
- [ ] **W4b:** admin — write `admin_logs` on the actions the DFD names (reports, broadcasts, membership changes).
- [ ] **W4c:** admin — real `/reports` landing page instead of the `/dashboard` redirect.
- [ ] **W4d:** admin — system settings (gym name / QR target / inactivity threshold) persisted in a `settings` table.

## Task 5: Verify + commit

- [x] **Step 1:** `python -m py_compile ai-service/main.py ai-service/services/gemini.py ai-service/routers/identify_food.py` → exit 0.
- [x] **Step 2:** `flutter analyze --no-pub` → 0 new issues ("No issues found!").
- [x] **Step 3:** `flutter build web --release` → succeeds ("✓ Built build\web", 56.0s).
- [ ] **Step 4 (manual, device/emulator):** Add Food → pick meal type → Capture → photo identifies (HTTP 200, Filipino dish) → candidate correction → portion → Save → row in `meal_logs` **and** `food_identification_logs`; kill the AI service → Save shows inline error + Retry; unmatched dish → hint + search + still saveable.
- [ ] **Step 5:** commit `fix(mobile): food intake flow rebuild + AI service reachability (port/model/env)`.

