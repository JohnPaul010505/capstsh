# Food Intake Wizard + PhilFCT Data Import — Design

Date: 2026-09-25
Status: approved for implementation
Supersedes: `2026-09-22-food-intake-and-ai.md` (the AI photo-identification design)

## 1. Intent

Replace the AI-driven food logging flow with a pure, database-driven wizard.
The member captures a photo first (the photo is a record only — it is never
analysed), then picks a meal type, searches the real FNRI/PhilFCT database,
enters a quantity in grams, reviews the auto-calculated nutrition, and saves.

`nutrition_foods` becomes authoritative FNRI/PhilFCT data instead of the
manually estimated Filipino-dish seed rows.

Success criteria:

1. A member can log a meal end-to-end with **zero AI dependency** (the AI
   service can be down and the flow still works).
2. The food search returns real FNRI foods (1,542 items) with Filipino
   alternative names, not estimates.
3. Nutrition is calculated from the authoritative per-100 g values, never
   guessed.

## 2. Member flow (full-screen wizard, one step at a time)

```
Step 1  Add photo     capture | gallery | Skip           (photo optional)
Step 2  Meal type     breakfast | lunch | dinner | snack (required)
Step 3  Search food   search nutrition_foods (FNRI)      (required)
Step 4  Quantity      grams, default 100 g              (required, > 0)
Step 5  Review        photo, meal type, food, grams, macros (editable)
Step 6  Saved         writes meal_logs; ring + list refresh
```

- Full-screen route pushed from the food intake screen; a progress indicator
  shows the current step. Back navigates to the previous step; close cancels.
- Step 1: camera or gallery via `image_picker` (same constraints as today:
  max 1024 px, quality 85). **No** network call is made for the photo. The
  image is uploaded to the `proofs` bucket at save time
  (`meals/<userId>/<epoch>.jpg`) and stored in `meal_logs.photo_url`.
  Skipping is allowed; the meal still saves.
- Step 3: `NutritionService.searchFoods` calls the
  `search_nutrition_foods(text)` Supabase RPC. The RPC searches the FNRI
  English name, food group, and Filipino aliases (the `text[]` alias column
  cannot be reliably searched with a PostgREST table filter). Each row shows
  name, Filipino alternative name when present, food group, and kcal per 100 g.
  No result → the member cannot continue (there is no manual-entry fallback
  in this design).
- Step 4: grams input, default `100`. Nutrition preview updates live:
  `value = (grams / 100) × per-100 g value`.
- Step 5: review shows everything; the member may go back to any earlier step
  (edit links) before saving. Save is disabled until meal type, food and
  grams are set.
- Step 6: insert into `meal_logs`, then `ref.invalidate(todayMealsProvider)`
  so the kcal ring, macro bars and meals list refresh. Save failures show an
  inline error with a Retry button; the wizard stays on the review step.

## 3. AI removal (food intake scope)

Removed:

- `meal_log_page.dart`: `_AiStep`, `_uploadAndIdentify`, candidate chips,
  AI portion autofill, the AI food-recommendations card and its
  `FoodRecommendationService` usage.
- `mobile/fitness_app/lib/features/shared/services/food_recommendation_service.dart`
  (file deleted; no other screen imports it).
- `ai-service/routers/identify_food.py` and `ai-service/routers/food.py`
  (files deleted), their registrations in `ai-service/main.py`, the
  `FoodRecommendation` schema in `ai-service/schemas.py`, and
  `food_recommendations_ai` in `ai-service/services/gemini.py`.
- `admin/server/index.js`: the `/api/ai/identify-food` proxy route and its
  entry in the `/api/health` route list.

Kept (out of scope): `predictions` and `met` routers, `goal_adjustments_ai`,
`gemini` service, all database tables (`food_identification_logs`,
`food_recommendations` are left in place — no destructive migration).

## 4. PhilFCT import (SQL migration, applied via Supabase SQL editor)

New migration `supabase/migrations/00029_philfct_nutrition_foods.sql`:

1. `alter table public.nutrition_foods add column if not exists fnri_id text;`.
2. Drop `idx_nutrition_foods_fnri_id` and delete all existing
   `nutrition_foods` rows **before** rebuilding the unique index. This cleans
   up a previous partial/manual import and prevents duplicate-key failures.
3. Rebuild the partial unique index on non-null `fnri_id` values.
4. Create `search_nutrition_foods(text)`, a `SECURITY INVOKER` RPC that
   searches the English name, food group, and Filipino aliases. Existing
   `nutrition_foods` read RLS remains in force; execution is granted to
   `authenticated` members.
5. `insert` of all 1,542 foods generated from
   `nedpals/fct-fnri-api` (`data/foods/index.json` + per-food JSON):

| Column           | Source                                    |
| ---------------- | ----------------------------------------- |
| `fnri_id`        | `id` (e.g. `A001`)                        |
| `food_name`      | `name`                                    |
| `aliases`        | `[alternative_name]` when it is not `N/A` |
| `category`       | `food_group`                              |
| `serving_label`  | `'100 g'`                                 |
| `serving_size_g` | `100`                                     |
| `calories_kcal`  | `measurements` → `energy_calculated_kcal` |
| `protein_g`      | `nutrients` → `protein_g`                 |
| `carbs_g`        | `nutrients` → `carbohydrate_total_g`      |
| `fat_g`          | `nutrients` → `total_fat_g`               |
| `source`         | `'DOST-FNRI PhilFCT'`                     |

Every FNRI value is per 100 g, which is exactly what the grams-based quantity
step expects. Foods missing a value insert `0`.

The migration is a generated SQL file (no runtime script): the data is baked
in so applying it is a single paste into the SQL editor.

## 5. Code layout

| File | Change |
| ---- | ------ |
| `mobile/fitness_app/lib/features/member/meals/pages/meal_log_page.dart` | Slimmed to list + ring + "Add Food" → push wizard |
| `mobile/fitness_app/lib/features/member/meals/pages/add_food_wizard.dart` | New: the 5-step wizard |
| `mobile/shared/lib/services/nutrition_service.dart` | Calls the FNRI name/alias search RPC |
| `ai-service/main.py`, `routers/*.py`, `schemas.py`, `services/gemini.py` | AI food endpoints removed |
| `admin/server/index.js` | identify-food proxy removed |
| `supabase/migrations/00029_philfct_nutrition_foods.sql` | New: FNRI data import |

## 6. Verification

- `flutter analyze --no-pub` → 0 new issues.
- `flutter build web --release` → succeeds.
- `python -m py_compile` over the ai-service modules → exit 0.
- SQL: `select count(*) from nutrition_foods` = 1,542; spot-check a food
  (e.g. `Corn grits, white`: 357 kcal, 8.3 P, 77.5 C, 1.5 F per 100 g).
- Manual walk: Add Food → photo → skip → lunch → search "corn grits" →
  150 g → macros scale by 1.5 → review → save → ring and list update.

