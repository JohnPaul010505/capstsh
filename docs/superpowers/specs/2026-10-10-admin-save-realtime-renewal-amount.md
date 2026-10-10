# Spec — Admin edit-save failures, realtime profile sync, renewal amount

Date: 2026-10-10
Status: brainstormed → planned → executing

## Concerns raised (all five)

| # | Concern | Verdict |
|---|---------|---------|
| 1 | Onboarding step indicator should sit **above the logo** | Layout move, mobile |
| 2 | Admin **member details** edit cannot be saved | Real bug, root-caused |
| 3 | Admin **trainer details** edit cannot be saved | Investigated live, hardening + error surfacing |
| 4 | Admin must be able to edit the member's **email**, and it must update **realtime across the whole system** and persist to Supabase | Feature + realtime |
| 5 | Membership **renewal approval must capture the amount** ("how much is that"), show details, and update **total revenue** | Feature |

## Root cause of #2 (verified against the live database)

`useUpdateMember` posts every form key, including `date_of_birth: ''` for a member
with no birthday. `profiles.date_of_birth` is a `date` column, so Postgres
rejects the whole statement and **nothing** is written:

```
PATCH /rest/v1/profiles?id=eq.<member>  (as the signed-in admin)
HTTP 400 {"code":"22007","message":"invalid input syntax for type date: \"\""}
```

Reproduced twice — once with the real admin JWT and once with the service role —
so it is a payload bug, **not** RLS. The admin `update` policy
(`public.is_admin()`) is fine; the same request with a valid date succeeds.

Why it looked like "nothing happens": the mutation throws, React Query has no
`onError`, and no toast exists — the Save button just stopped spinning.

## Decisions

### #1 Indicator above the logo
`_NamedStepHeader` moves to the first child of the column, above
`_buildLogoHero()`. Same widget, same 4 steps; nothing else changes.

### #2/#3 Save that actually saves
- Empty string is only valid for `text` columns. The payload is normalised:
  `date_of_birth` empty → `null`; every other string is trimmed, and a
  trimmed-empty optional field is sent as `null` (never `''` for `date`).
- `email` is validated non-empty before the request is sent.
- Failures become visible: an inline error banner under the Save button
  carrying the Supabase message (`err.message`), instead of silence.
- Success invalidates both the list key and the detail key
  (`['members']` + `['member', id]`, `['trainer', id]` + `['trainers']`).
- A shared `profileUpdates.ts` helper holds the normaliser so member and
  trainer pages cannot drift apart again.

### #4 Email + realtime
- **Editable**: Email joins the member Personal Information grid (it is a
  `text` column on `profiles`, already covered by the admin update policy).
- **Realtime**: `profiles` is not in the `supabase_realtime` publication, so
  `.stream()` on it fails today. Migration `0041` adds `profiles`,
  `memberships` and `membership_renewal_requests` to it (idempotent, same
  `do $$` shape as `0039`).
- **Mobile**: `AuthNotifier` keeps one `profiles` subscription filtered to the
  signed-in user's id and calls `refreshProfile()` on any change. Every screen
  that reads `authProvider` (home greeting, profile page, trainer header)
  updates live; `activeUserIdProvider` keeps it user-scoped.
- **Admin**: a `useRealtimeProfiles()` hook invalidates the profile-keyed
  queries on any `profiles` change, so the Members/Trainers pages move without
  a reload. Writes still go straight to Supabase (single source of truth) —
  realtime is only the fan-out.

### #5 Renewal amount
- Migration `0041` adds `requested_price` and `approved_price numeric(10,2)`
  to `membership_renewal_requests`. The mobile sheet lets a member state the
  amount they were quoted; the admin confirms/overrides it.
- The renewal drawer keeps its existing details (member, code, email, plan,
  months, note, requested on) and **adds**: the member's current membership
  (plan, price, end date), the member's requested window, and a required
  **Amount collected (₱)** field defaulted to the requested price, else the
  plan price, else the current membership price.
- Approving writes the membership with **that** price instead of guessing, then
  marks the request `approved` with `decided_price`. The Revenue tab sums
  `memberships.price` by `start_date`, so Total Revenue moves with it; the
  approve path also invalidates the `['dash-revenue', …]` keys.
- Decline is unchanged.
- The member sees the decided amount on their next read
  (`MembershipRenewalRequest.approvedPrice`).

## Out of scope
- Payment gateways / receipts / invoices.
- Editing `auth.users.email` (login credential). `profiles.email` is the record
  the app reads; changing the credential needs the admin API and is a separate
  security decision.

## Verification
- `cd admin && npx tsc --noEmit` clean.
- `cd mobile/fitness_app && flutter analyze --no-pub` clean.
- Live REST probe: approve-shaped update as the signed-in admin returns 200 and
  the row changes (re-run the probe script, not just the type checker).
- Browser check on the running admin dev server for both save flows.
