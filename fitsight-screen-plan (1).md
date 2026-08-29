# FitSight — Food Intake Screen Plan

## 1. Food Intake Screen

### 1.1 Core problem
- Pure manual entry: members don't know exact nutrition values → inaccurate and a hassle.
- Pure AI-generated numbers from a photo: unprovable/undefendable accuracy.
- **Solution: hybrid pipeline** — AI identifies the food, a verified nutrition database supplies the numbers, the member confirms.

### 1.2 Data flow
1. Member taps **Take Photo** or **Gallery** (existing).
2. Vision AI identifies the food → returns candidate food name(s), not nutrition numbers.
3. App looks up the identified food in a **verified nutrition database** (DOST-FNRI PhilFCT for Philippine dishes; USDA FoodData Central as fallback) for a standard serving.
4. Calories/Protein/Carbs/Fat fields **auto-fill** from that lookup.
5. Member reviews, taps the correct AI candidate if more than one is offered, and adjusts portion/values if needed (fields stay editable).
6. Member taps **Log Meal** to save.

### 1.3 Technical decisions (resolving code-agent review)
These resolve the blocking gaps raised in review before implementation starts:

| Concern | Decision |
|---|---|
| `meal_records` vs `meal_logs` schema conflict | Use **`meal_logs`** — it already has `photo_url`, which the whole AI pipeline depends on, and it's what the current `MealLogPage` code inserts into. Treat `meal_records` as legacy/unused for this feature. |
| Nutrition data source & access pattern | No public FNRI bulk API exists. Seed a **Supabase `nutrition_foods` table** manually from the PhilFCT lookup tool (see 1.11 — starter template provided) rather than calling FNRI live. This also removes the gym-connectivity risk: nutrition lookup becomes a local DB query, not an external API call per photo. |
| Portion scaling | Add `serving_size_g` + `serving_label` to `nutrition_foods`. UI uses preset multiplier chips (0.5×/1×/1.5×/Custom) rather than free-text edits. Formula: `calories = db_calories × (actual_portion_g / db_serving_size_g)`, same scaling applied to protein/carbs/fat. |
| Vision API | **Google AI Studio / Gemini multimodal API.** Accepts image input directly, supports forced structured JSON output (matches the `{"candidates":[{"name":..., "confidence":...}]}` contract below). Prompt includes the current `nutrition_foods` name list so Gemini prefers matching against known dishes — implements the "constrain the guess space" accuracy lever from 1.6. API key is stored as the `GEMINI_API_KEY` environment variable (never committed to the repo, never hardcoded) — set locally via `.env` (gitignored) and in production via the hosting platform's secret manager. **Do not build/fine-tune a custom model for V1** — that's a separate future-work phase, not part of this screen. |
| Image transport | Member's photo uploads to Supabase Storage first (already implemented), then the storage URL — not raw bytes — is passed to the new AI endpoint. |
| New AI endpoint | `POST /api/ai/identify-food` — accepts an image URL, returns `{"candidates": [{"name": string, "confidence": number}]}`. Backend then matches each candidate name against `nutrition_foods` for the lookup. |
| Update strategy for nutrition data | Manual seed migration now (from the starter template); future additions via an admin-side insert/update, no live sync needed since PhilFCT has no API to sync against. |

### 1.4 Implementation order
1. **Schema**: consolidate on `meal_logs`, create `nutrition_foods` table (see 1.11 for fields), seed it from the filled-in starter template.
2. **Vision + nutrition source**: pick the vision API, write a small integration spike, confirm the candidate response format.
3. **AI service endpoint**: build `/api/ai/identify-food`.
4. **Nutrition lookup + portion scaling**: implement as a Supabase RPC or in the AI service, including the scaling formula above.
5. **Flutter screen**: photo capture → upload → vision call → candidate chips → auto-fill editable fields → calorie ring + macro cards from `todayMealsProvider` → save to `meal_logs`.
6. **Riverpod provider math**: `todayMealsProvider` totals computed via Atwater factors (P×4 + C×4 + F×9) for the ring/macro cards.
7. *(Optional)* Food-identification accuracy logging — new `food_identification_logs` table (`id`, `member_id`, `photo_url`, `ai_candidates`, `selected_food`, `member_edited`, `created_at`) if you want correction data as defense evidence.


### 1.5 Why this is defensible
- Food identification accuracy (~68–86% for generic, real-world/general-purpose models) is a separate, named metric from nutrition accuracy — it does not need to be "the" accuracy number for the whole system.
- Nutrition numbers come from DOST-FNRI (Philippine government body, lab-measured via nitrogen analysis, Soxhlet extraction, Atwater factors) or USDA — not from an AI guess.
- Member confirmation is the final human-in-the-loop check that catches misidentification or portion mismatch.
- Suggested defense framing: *"Food identification accuracy is the primary limiting factor, but is separate from nutrition accuracy; once food is correctly identified, nutrition values come from a verified reference database rather than an AI estimate. Member confirmation of the identified food and portion size is the final check before logging."*

### 1.6 Improving food identification accuracy (pushing past the 68–86% general baseline)
1. **Fine-tune on a Filipino/local food dataset** rather than using a generic global classifier — this is the single biggest lever. Comparable regional-cuisine studies show this jump clearly: a CNN fine-tuned on a regional Southeast Asian food dataset (South Kalimantan) reached 94.5% accuracy; a Thai-food-specific model reached 91.49% (up from 84.06% with a generic approach) using transfer learning on a dedicated local dataset (THFOOD-50).
2. Constrain the AI's possible answers to foods that exist in your FNRI-backed database — removes irrelevant guesses entirely.
3. Show top 2–3 candidates as tappable chips instead of silently picking one — leverages the model's stronger top-k (top-3/top-5) accuracy, which is always higher than its top-1 accuracy, rather than being capped by a single best guess.
4. Prompt for a clear, well-lit, top-down photo.
5. (Stretch) Log member corrections over time as accuracy data — usable as evidence in your defense.

**Realistic target for the defense:** general-purpose food recognition sits around 68–86%, but fine-tuning on a Filipino-food-specific dataset combined with top-3 candidate confirmation can realistically push effective accuracy into the low-to-mid 90s% — citable against the regional-cuisine fine-tuning studies above, not an invented number.

### 1.7 How kcal is calculated
Calories are derived from macros via the **Atwater factors** (same standard FNRI uses):
```
Total kcal = (protein_g × 4) + (carbs_g × 4) + (fat_g × 9)
```
Fat contributes more than double the calories per gram vs. protein/carbs — relevant for any visual (like the calorie ring) that represents macro proportions, since it should be weighted by *calorie contribution*, not raw grams.

### 1.8 Redesigned UI (no daily-goal comparison — self-referential only)
- **Calorie ring**: 3-segment donut colored by macro (protein = blue, carbs = amber, fat = green), each segment sized by that macro's *calorie contribution* (not grams). Total kcal shown in the center.
- **Macro mini-cards** (protein/carbs/fat): grams + % share of today's total calories, with a small progress bar colored to match the ring. No external daily target — purely today's own breakdown.
- **Meal cards** (Meals Today list): food photo thumbnail, name, calories, and small colored macro pills (protein/carbs/fat) per meal — replaces the current bare list.
- **Log Meal card**:
  - Photo preview area (existing Take Photo / Gallery).
  - AI candidate chips row ("Chicken adobo ✓", "Pork adobo", "Type manually") shown after a photo is taken — tap to confirm/correct identification.
  - Auto-filled Calories/Protein/Carbs/Fat fields, still editable.
  - Small caption: "Auto-filled from FNRI standard serving · edit if needed" for transparency.

### 1.9 Fallback paths
- **No confident AI match**: show "Couldn't identify this food — select from the list or enter manually," fall back to a searchable food-database picker.
- **Manual entry without a photo**: still try to match the typed food name against the FNRI database and auto-fill macros from that match, rather than pure free-typing — keeps the "grounded in a real database" safeguard even without a photo.

### 1.10 Implementation notes (current codebase: `MealLogPage`, Flutter + Supabase)
- Existing fields to keep: `meal_type`, `food_name`, `calories`, `protein_g`, `carbs_g`, `fat_g`, `photo_url`.
- New pieces needed:
  - Vision API call after photo selection (candidate food name(s) + confidence).
  - Nutrition database lookup (FNRI/USDA) keyed by identified food name, returning calories/protein/carbs/fat per standard serving.
  - UI state for candidate chips + auto-fill + "auto-filled" caption.
  - Ring/macro-card widgets computed from `todayMealsProvider` totals using the Atwater-factor proportions above.

**Gemini prompt template** (sent from the AI service, with the image and the current `nutrition_foods.food_name` list injected):
```
You are identifying a food item from a photo for a Filipino fitness app.

Known foods (prefer matching one of these if the image resembles it):
[comma-separated list of nutrition_foods.food_name values]

Analyze the attached image and return the top 3 most likely food matches as JSON only, no other text:
{
  "candidates": [
    {"name": "<food name, prefer an exact match from the known foods list>", "confidence": <0.0-1.0>},
    ...
  ]
}

If the food is not in the known list, still return your best guess for "name" but note it may need manual entry.
```
API key: `GEMINI_API_KEY` environment variable — never hardcoded, never committed to the repo.

### 1.11 `nutrition_foods` table schema + starter data
Since PhilFCT has no bulk API, this table is seeded manually from a spreadsheet compiled via the PhilFCT lookup tool.

| Field | Type | Purpose |
|---|---|---|
| `id` | uuid | primary key |
| `food_name` | text | canonical name — matched against AI candidate output |
| `aliases` | text[] | alternate names (e.g. "Adobong Manok" for "Chicken Adobo") to improve match rate |
| `category` | text | e.g. Viand, Rice/Grain, Soup, Snack — used for the fallback picker |
| `serving_label` | text | human-readable serving description (e.g. "1 cup, cooked") |
| `serving_size_g` | numeric | grams the nutrient values are based on — required for portion scaling |
| `calories_kcal` | numeric | per serving |
| `protein_g` | numeric | per serving |
| `carbs_g` | numeric | per serving |
| `fat_g` | numeric | per serving |
| `source` | text | e.g. "DOST-FNRI PhilFCT" — kept for citation in the defense |

A starter workbook (`nutrition_foods_template.xlsx`) has been prepared with ~50 common Filipino dishes across these categories, ready to fill in from the PhilFCT lookup tool (`https://i.fnri.dost.gov.ph/fct/library/starting_pg`). It includes a formula-driven `calc_check_kcal` column (Atwater cross-check) to catch data-entry mistakes before seeding.

---

## 2. Open / next steps
- [ ] Fill in `nutrition_foods_template.xlsx` from the PhilFCT lookup tool (this is the current blocker — do this first).
- [ ] Migrate/seed `nutrition_foods` table in Supabase from the filled-in template.
- [ ] Consolidate on `meal_logs` (drop/ignore `meal_records` for this feature).
- [ ] Pick the vision API for food identification, build `/api/ai/identify-food`.
- [ ] Build the candidate-chip UI, portion-scaling control, and auto-fill logic in `MealLogPage`.
- [ ] Build the calorie ring + macro mini-cards + richer meal cards.
- [ ] (Future work, not V1) Fine-tune a vision model on a Filipino-food-specific dataset to push accuracy well above the general-purpose baseline (see 1.6).
- [ ] (Optional) Small validation test: run ~20–30 known foods through the identification pipeline, compare against FNRI ground truth, report accuracy (e.g., MAPE) for the defense.
- [ ] (Optional) `food_identification_logs` table for accuracy/correction tracking as defense evidence.
