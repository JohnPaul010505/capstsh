# Onboarding Step Fixes Plan

## Context
The onboarding splash screen has 4 steps. After recent changes, Flutter Web console shows:
- 404s for `assets/assets/profiles/L1.gif` (double `assets/` prefix)
- Pointer assertion errors on Flutter Web (non-blocking)
- Gender cards in step 3 show icons instead of the assigned GIFs
- Steps 1–4 content is left-aligned instead of centered
- Buttons in steps 1 and 3 have unwanted highlight/selected styling
- Profile GIFs in step 4 exist but may not animate

## Root Cause Analysis
1. **Double `assets/` prefix**: `ClayAvatar` uses `Image.network()` for all `avatarUrl` values. The DB stores `assets/profiles/L1.gif`. On web, the dev server resolves it as a network path, prepending another `assets/`, producing `assets/assets/profiles/L1.gif` → 404.
2. **Gender GIFs not shown**: `_genderCard()` renders only an `Icon`, never the `gifAsset` parameter.
3. **Left-aligned steps**: Each step's root `Column` uses `crossAxisAlignment: CrossAxisAlignment.start`.
4. **Button highlights**: `_genderCard()` applies selected-state border, shadow, and checkmark; step 1 has no highlight issue itself but step 3's cards do.
5. **Animation**: GIF files (`L1.gif`–`L3.gif`, `W1.gif`–`W3.gif`) already exist in `assets/profiles/`. `Image.asset` natively animates GIFs — no extra code needed once the asset widget is used.

## Decision: avatar_url storage format
Store the relative asset path `assets/profiles/L2.gif` in `profiles.avatar_url`. All display widgets (`ClayAvatar`, settings page avatar) must branch on the prefix:
- Starts with `assets/` → `Image.asset(imageUrl)`
- Otherwise → `Image.network(imageUrl)` (existing behavior for remote URLs)

This avoids a storage migration and keeps the DB value meaningful.

## Files to Modify

### 1. `lib/features/shared/widgets/clay/clay_avatar.dart`
- In `build()`, replace the single `Image.network` with a branch:
  ```dart
  imageUrl != null
      ? (imageUrl!.startsWith('assets/')
          ? Image.asset(imageUrl!, width: _size, height: _size, fit: BoxFit.cover)
          : Image.network(imageUrl!, width: _size, height: _size, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildInitials(isDark)))
      : _buildInitials(isDark)
  ```

### 2. `lib/features/member/settings/pages/settings_page.dart`
- Same branch for the avatar image (line ~124 `Image.network(avatarUrl, ...)`):
  ```dart
  avatarUrl!.startsWith('assets/')
      ? Image.asset(avatarUrl, width: 52, height: 52, fit: BoxFit.cover)
      : Image.network(avatarUrl, width: 52, height: 52, fit: BoxFit.cover,
          errorBuilder: ...)
  ```

### 3. `lib/features/member/onboarding/pages/onboarding_splash_screen.dart`
Three changes:

**a) Center all step content**
- Change each step's root `Column` `crossAxisAlignment` from `CrossAxisAlignment.start` → `CrossAxisAlignment.center`
- Change inner text alignments from `CrossAxisAlignment.start` to `center` where needed
- Step 2 inputs already have their own internal layout; center the step column but keep inputs left-aligned internally

**b) Step 3 — show GIF in gender cards, remove highlight**
- Update `_genderCard()` to accept and display `gifAsset`:
  - Add `Image.asset(gifAsset, height: 70, width: double.infinity, fit: BoxFit.cover)` above the icon
  - Remove the `if (selected) ...[ Icon(check_circle) ]` block
  - Keep border/shadow neutral (no selected accent change) — all cards look the same
  - Keep `onTap` → `_selectGender(value)` so selection still works logically, but visually all cards are identical

**c) Step 4 — confirm profile GIFs display correctly**
- Already uses `Image.asset` with correct paths (`assets/profiles/...`). No change needed.
- GIF animation works automatically via `Image.asset`.

### 4. `lib/shared/widgets/step_indicator.dart`
- Verify the straight-line indicator renders centered below the card (already implemented from prior work — no change expected, just validate).

## Summary of Step Behavior After Fix
| Step | Content | Buttons | Notes |
|------|---------|---------|-------|
| 1 | Welcome text + Start | Full-width, no highlight | Centered |
| 2 | Height/Weight/BMI inputs | Back + Next | Centered column |
| 3 | Male (L2.gif) / Female (W3.gif) cards | Back + Next | No selected highlight; GIFs animate |
| 4 | L1/L2/L3 or W1/W2/W3 selector | Save | Centered; GIFs animate; saves path to DB |

## Validation
1. `flutter analyze` — zero errors/warnings across onboarding, home, settings, clay_avatar, step_indicator
2. Run `flutter run -d chrome` and confirm:
   - Step 3 shows L2.gif and W3.gif animating in the gender cards
   - Step 4 shows L1/L2/L3 or W1/W2/W3 animating
   - All step content is centered
   - No 404s for profile assets in console
   - After Save, home page avatar shows selected GIF
   - Settings page avatar shows selected GIF

## Risks
- Existing users with `avatar_url` set to a remote URL (HTTP/HTTPS) are unaffected — the `startsWith('assets/')` branch falls through to `Image.network`.
- Existing users with `avatar_url = null` continue to see initials/gradient fallback.
