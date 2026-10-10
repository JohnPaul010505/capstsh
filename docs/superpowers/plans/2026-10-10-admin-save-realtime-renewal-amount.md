# Plan — Admin edit-save failures, realtime profile sync, renewal amount

Spec: `docs/superpowers/specs/2026-10-10-admin-save-realtime-renewal-amount.md`

Ordered so each step is verifiable on its own.

## Step 1 — Onboarding indicator above the logo
- `onboarding_splash_screen.dart`: swap `_buildLogoHero()` and
  `_NamedStepHeader(...)` in the column (indicator first, then logo, then card).
- Check: `flutter analyze --no-pub`.

## Step 2 — Migration `0041_profiles_realtime_and_renewal_price.sql`
- Add `profiles`, `memberships`, `membership_renewal_requests` to
  `supabase_realtime` (idempotent `do $$` loop like `0039`).
- `alter table membership_renewal_requests add column if not exists
  requested_price numeric(10,2), add column if not exists approved_price
  numeric(10,2)` + column comments.
- Check: apply with the service role against the live project (psql/REST), then
  probe that the new columns exist.

## Step 3 — Shared payload normaliser (admin)
- New `admin/src/features/shared/profileUpdates.ts`: `normalizeProfileUpdates()`
  (trim, `''` → `null` for date) and `describeError()`.
- Check: `npx tsc --noEmit`.

## Step 4 — Member detail save + email
- `MemberDetailPage.tsx`: add `email` + `full_name` to the editable grid,
  normalise through the helper, inline error banner, invalidate
  `['members']` **and** `['member', id]`.
- Check: `npx tsc --noEmit`; live REST probe; browser save.

## Step 5 — Trainer detail save
- `TrainerDetailPage.tsx`: same normaliser, error banner, invalidate
  `['trainer', id]` + `['trainers']`.
- Check: `npx tsc --noEmit`; browser save.

## Step 6 — Realtime
- `admin/src/hooks/useRealtimeProfiles.ts`; call it from `MemberDetailPage`,
  `TrainerDetailPage`, `MembersPage`, `TrainersPage` (invalidate profile keys).
- Mobile `auth_provider.dart`: `profiles` realtime subscription for
  `auth.uid()` → `refreshProfile()`; cancel on dispose.
- Check: `flutter analyze --no-pub`, `npx tsc --noEmit`; live PATCH from REST
  moves the mobile/admin UI (verified via the REST probe + page reload).

## Step 7 — Renewal amount
- `useMemberships.ts`: `useRenewalRequests()` selects `requested_price`,
  `approved_price`; approve mutation takes `price`.
- `types/index.ts`: extend `MembershipRenewalRequest` with
  `start_date`, `end_date`, `requested_price`, `approved_price`.
- `MembershipsPage.tsx`: drawer shows current membership + requested window +
  required Amount field; approve inserts the membership at that price and
  records `approved_price`; invalidate `['dash-revenue']`.
- Mobile `membership_renewal_request.dart` + `submitRenewalRequest`: member may
  state a quoted amount (`requested_price`) and sees `approvedPrice`.
- Check: `npx tsc --noEmit`, `flutter analyze --no-pub`, live approve probe.

## Step 8 — Commit + verify
One commit per step, message prefixed `fix(admin)` / `feat(admin)` /
`feat(mobile)`; final `npx tsc --noEmit` + `flutter analyze --no-pub` clean.
