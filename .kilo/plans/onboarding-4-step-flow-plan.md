# Onboarding Flow Plan

## Goal
Create a 4-step onboarding flow for new users that collects height, weight, gender, and profile picture selection. The flow should be accessible after login only for new users, and after completion the user lands on the dashboard with their data saved.

## Step Indicator Design
**Straight line progress bar** — not broken/dotted. A horizontal line that fills with color as the user completes each step. The line should be continuous, with no gaps between segments.

Example: `[¦¦¦¦¦¦¦¦¦¦]` where `¦` is filled color and `¦` is unfilled/gray

## Onboarding Steps

### Step 1 — Welcome
**Layout:**
- Logo at top of screen (above the container, visible on all steps)
- Container with:
  - Heading: `"Welcome to Capshi"`
  - Description: `"Let's set up your profile — just 4 quick steps."`
  - **Start** button at bottom of container
- Step indicator below container: `1 / 4` with straight line

**Action:** Pressing **Start** advances to Step 2

---

### Step 2 — Height & Weight
**Layout:**
- Container with:
  - Heading: `"Your Stats"`
  - Height input field (cm) — numeric, 140–210 cm
  - Weight input field (kg) — numeric, 35–150 kg
  - Live BMI calculator showing:
    - BMI value (updates as user types)
    - BMI category label with color
  - **Back** button ? returns to Step 1
  - **Next** button ? enabled only when height and weight are both valid
- Step indicator below container: `2 / 4` with straight line

**Validation:**
- Height: 140–210 cm
- Weight: 35–150 kg
- Next button disabled until both fields are valid

---

### Step 3 — Gender Selection
**Layout:**
- Container with:
  - Heading: `"About You"`
  - Two cards side by side:
    - **Male card**: shows `c:\capstsh\mobile\fitness_app\assets\profiles\L2.gif`
    - **Female card**: shows `c:\capstsh\mobile\fitness_app\assets\profiles\W3.gif`
  - Tapping a card selects it (highlighted border/background)
  - **Back** button ? returns to Step 2
  - **Next** button ? enabled only when gender is selected
- Step indicator below container: `3 / 4` with straight line

---

### Step 4 — Profile Picture Selection
**Layout:**
- Container with:
  - Heading: `"Choose Your Profile"`
  - If male selected in Step 3, show 3 male GIFs:
    - `c:\capstsh\mobile\fitness_app\assets\profiles\L1.gif`
    - `c:\capstsh\mobile\fitness_app\assets\profiles\L2.gif`
    - `c:\capstsh\mobile\fitness_app\assets\profiles\L3.gif`
  - If female selected in Step 3, show 3 female GIFs:
    - `c:\capstsh\mobile\fitness_app\assets\profiles\W1.gif`
    - `c:\capstsh\mobile\fitness_app\assets\profiles\W2.gif`
    - `c:\capstsh\mobile\fitness_app\assets\profiles\W3.gif`
  - Tapping a GIF selects it (highlighted border/overlay)
  - **Save** button at bottom of container
- Step indicator below container: `4 / 4` with straight line fully filled

---

### After Save (Step 4 Complete)
1. System saves all onboarding data to Supabase:
   - Height, weight, BMI
   - Gender
   - Selected profile GIF path/URL
   - Marks onboarding as complete (`needs_onboarding = false`)
2. User is navigated to the **Dashboard**
3. BMI data appears on the **BMI page**
4. Selected profile GIF replaces the `JP` avatar on the **Home screen** (right side)
5. **Settings page** updates to show:
   - Profile picture at top
   - Name below it
   - Email below the name

---

## Visual Layout Summary
```
[Logo] ? top of screen, persistent across all steps

[Step Container]
  - Step content (varies by step)
  - Buttons (Back/Next/Save) ? inside container at bottom

[Step Indicator] ? below container, straight line progress bar
```

---

## Technical Requirements

### Step Indicator Component
- Straight horizontal line, not broken/dotted
- Fills with `ClayTokens.clayPrimary` color as steps are completed
- Unfilled portion is gray/neutral
- Shows step numbers or just visual fill

### Navigation Flow
- Login ? check `needs_onboarding` flag
- If true ? show onboarding
- If false ? go to dashboard
- Onboarding steps navigate forward/backward
- After Save ? mark onboarding complete ? navigate to dashboard

### Data Storage
- Save height, weight, gender, profile image selection to Supabase `profiles` table
- Update `needs_onboarding` to `false`
- Refresh `authProvider` to update UI across app

### Assets
- Male profile GIFs: `assets/profiles/L1.gif`, `L2.gif`, `L3.gif`
- Female profile GIFs: `assets/profiles/W1.gif`, `W2.gif`, `W3.gif`
- Logo: `assets/logo.png`

## Files to Modify
1. `lib/features/member/onboarding/pages/onboarding_splash_screen.dart` — restructure to 4-step flow
2. `lib/features/shared/widgets/step_indicator.dart` — new straight line progress indicator
3. `shared/lib/services/auth_service.dart` — add `completeOnboarding()` method
4. `shared/lib/providers/auth_provider.dart` — add `completeOnboarding()` method
5. `lib/features/member/settings/pages/settings_page.dart` — update profile display
6. `lib/features/member/home/pages/home_page.dart` — update avatar display
