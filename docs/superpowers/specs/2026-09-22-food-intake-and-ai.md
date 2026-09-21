# Food Intake Flow Rebuild + AI Recommendation Enablement

> **Status:** Approved
> **Date:** 2026-09-22
> **Scope:** Mobile food-intake (meal logging) flow, AI service reachability, AI food recommendation.
> **Excluded by owner:** AI "Detect Inactive Members" (admin inactive report stays on the 7-day rule), per-member QR codes.

## Problem

The member FOOD INTAKE flow (`mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart`)
does not work end-to-end, and the AI food recommendation required by Chapter 1 Objective 6 and
Figure 26 («Generate Food Recommendation») is not reachable from the app at all.

Verified root causes:

1. **The AI service is unreachable from every consumer.**
   - `API_BASE_URL` is absent from both `mobile/fitness_app/.env` and `assets/.env`, so
     `_getApiBaseUrl()` (meal_log_page.dart:440) falls back to `http://localhost:3001`.
   - The AI service binds port **8000** (`ai-service/main.py:36`), while the mobile fallback *and*
     the admin Vite proxy (`admin/vite.config.ts` → `'/api': 'http://localhost:3001'`) target **3001**.
2. **The vision call cannot succeed even when reachable.**
   - `routers/identify_food.py:22` uses model `gemini-3.6-flash`, which does not exist for
     `google-generativeai==0.8.4` → every call raises → HTTP 502.
   - The service fetches the photo over plain `httpx` (no Supabase token) from the `proofs` bucket
     public URL; migration `00014` only grants `storage.objects` policies `to authenticated`, so the
     bucket must be **public** or every identify call fails with "Failed to fetch image".
3. **The recommendation endpoint loses all member context** (`routers/food.py`):
   - reads `profiles.age` and `profiles.fitness_goal` — neither column exists (profiles has
     `date_of_birth`, `gender`; goals live in the `goals` table) → PostgREST 400 → `profile = {}`.
   - reads `meal_logs` ordered by `logged_at` — the real column is `meal_time` → query fails → `logs = []`.
4. **Gemini fallback dishes are Western** (Oatmeal, Greek Yogurt, Quinoa…) while Chapter 1 promises
   DOST-FNRI-aligned Filipino suggestions, and `nutrition_foods` is already seeded with Filipino
   dishes (Chicken Adobo, Sinigang, Sisig, …).
5. **Mobile never persists AI results:** it never calls `/api/ai/food-recommendations`, never writes
   `food_recommendations` (Table 18) and never writes `food_identification_logs` (Table 19) although
   the candidates, the selected dish and the "did we get this right?" correction are all in widget state.
6. **Flow defects in the form:**
   - meal type silently defaults to `breakfast` (`_mealTypeSelected` is tracked but not enforced);
   - an AI candidate that is not matched in `nutrition_foods` fills empty macro fields with no
     warning and no way to search the nutrition database from photo mode;
   - save errors are swallowed (`catch (_) {}` at meal_log_page.dart:495) → silent failure, no retry;
   - the progress indicator is faked while the service reports real `step` / `progress_percent`.

## Solution

### Phase 0 — make the AI service reachable (prerequisite for everything)
- Port becomes env-driven: `PORT` (default **3001** so the existing admin proxy and the mobile
  fallback are both correct with zero further changes).
- CORS becomes env-driven: `CORS_ORIGINS` (default `*`, `allow_credentials=False` — the app uses
  Bearer-free JSON calls, so wildcard is safe for the capstone demo).
- Gemini model becomes env-driven: `GEMINI_MODEL` (default `gemini-2.0-flash`, valid for
  `google-generativeai==0.8.4`); applied in both `services/gemini.py` and `routers/identify_food.py`.
- `API_BASE_URL=http://localhost:3001` added to `mobile/fitness_app/.env` and `assets/.env`.
- New `ai-service/.env.example` documenting `GEMINI_API_KEY`, `GEMINI_MODEL`, `PORT`, `CORS_ORIGINS`
  and the Supabase service variables used by `services/db.py`.
- Verification step that the `proofs` bucket is publicly readable (the identify call depends on it);
  if not, document the one-click fix (make bucket public) — required for the AI demo.

### Phase 1 — rebuild the FOOD INTAKE flow (mobile)
Keep the page structure (list + macro ring + add form) but make the flow explicit and dead-end free:

```
1. Meal type       breakfast | lunch | dinner | snack        REQUIRED before save
2. Input mode      Manual | Capture | Gallery
   ├─ Manual → search nutrition_foods (autocomplete) → pick → macros fill → editable
   └─ Photo  → upload to `proofs` → POST /api/ai/identify-food
               → candidate chips ("Did we get this right?") → member picks / edits
               → matched?  macros auto-fill from nutrition_foods (portion 0.5/1.0/1.5/custom g)
               → unmatched? macros stay editable + nutrition search available in photo mode
3. Save    → INSERT meal_logs (Table 17)
           → INSERT food_identification_logs (photo_url, ai_candidates, selected_food,
             member_edited) when the entry came from a photo
4. Errors  → surfaced inline with Retry; save errors are no longer swallowed
```

`member_edited` definition: the member changed the AI's top candidate (picked a different chip,
used the nutrition search to override, or edited the food name/macros after auto-fill).

## Database

- `meal_logs` — exists (`00003_add_missing_tables.sql`), matches Table 17, no change.
- `food_identification_logs` — exists (`00019_create_nutrition_foods.sql`), RLS already allows
  member self-insert (`auth.uid() = member_id`), no change.
- `food_recommendations` — exists (`00001_initial_schema.sql`, Table 18); Phase 2 optionally widens
  it with macro columns (migration `0022_food_recommendation_macros.sql`).
- `profiles`, `goals`, `nutrition_foods` — read-only for this change.
- `storage.buckets` `proofs` — must be public (or the identify call must switch to signed URLs).

## AI service contract

- `POST /api/ai/identify-food` `{image_url, top_k}` →
  `{candidates: [{name, confidence, serving_label?, serving_size_g?, calories_kcal?, protein_g?,
  carbs_g?, fat_g?, source?, matched}], step, progress_percent}`
  (raises 400 on unfetchable/blurry image, 500 when `GEMINI_API_KEY` is missing, 502 on model errors)
- `POST /api/ai/food-recommendations` `{member_id, meal_type}` →
  `[{food_name, portion, calories, protein_g, carbs_g, fat_g, reason}]`

## File-by-file changes

| File | Change |
|---|---|
| `ai-service/main.py` | env-driven `PORT` + `CORS_ORIGINS` |
| `ai-service/services/gemini.py` | env-driven `GEMINI_MODEL` |
| `ai-service/routers/identify_food.py` | env-driven `GEMINI_MODEL` |
| `ai-service/routers/food.py` | Phase 2: fix `meal_time` ordering + member context + Filipino fallbacks |
| `ai-service/.env.example` | new — documents `GEMINI_API_KEY`, `GEMINI_MODEL`, `PORT`, `CORS_ORIGINS`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY` |
| `mobile/fitness_app/.env`, `assets/.env` | add `API_BASE_URL=http://localhost:3001` |
| `mobile/.../member/meals/pages/meal_log_page.dart` | Phase 1: meal-type required, `member_edited` tracking, non-swallowed save errors + Retry, `food_identification_logs` write, nutrition search available in photo mode, progress mapping |
| `mobile/shared/lib/services/meal_recommendation_service.dart` | Phase 2: calls `/api/ai/food-recommendations`, persists to `food_recommendations` |
| `supabase/migrations/0022_food_recommendation_macros.sql` | Phase 2 optional macros on `food_recommendations` |
| `admin/src/App.tsx`, `Sidebar.tsx`, dashboard/logs | Phase 3 W4 (routes, sidebar, `admin_logs` writes) |

## Order of implementation

1. Phase 0 (config/port/model/CORS/env) → verify with `/api/health` + one identify call
2. Phase 1 (flow) → verify with `flutter analyze --no-pub` + `flutter build web --release` + manual script
3. Phase 2 (recommendation) → verify a row lands in `food_recommendations`
4. Phase 3 workstreams, one PR-sized change each

## Acceptance criteria

1. On a physical phone (not just localhost), photo → identify returns HTTP 200 with a Filipino dish.
2. Every photo log writes **both** `meal_logs` and `food_identification_logs`.
3. An AI dish missing from `nutrition_foods` can still be saved, with a visible "not in database" hint.
4. Save failures show an inline error with Retry (no silent swallowing).
5. Meal type must be chosen before Save is enabled (all modes).
6. After saving, AI suggestions appear and are stored in `food_recommendations`.
7. `flutter analyze --no-pub` → 0 new issues; `flutter build web --release` → succeeds.

