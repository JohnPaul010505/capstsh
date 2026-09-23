# Membership & QR UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (inline, chosen by the human partner) to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the New Membership drawer's selected buttons solid purple with a Custom start/end date range, turn the Renew button purple, give the Renewal tab real table lines plus an Actions column, and make the QR Pending action buttons clearly visible.

**Architecture:** Pure UI/presentation changes in two existing page components. No new files, no backend, no schema changes. The Custom range adds two fields to the existing local `form` state and makes the End Date field editable only in that mode.

**Tech Stack:** React 18 + TypeScript + Tailwind (arbitrary value colors, e.g. `bg-[#7C3AED]`), lucide-react icons, existing `PLANS` / `addDays` helpers.

**Spec:** User request 2026-09-24 (4 items, screenshots supplied).

## Global Constraints

- Primary purple is `#7C3AED`, hover `#6D28D9`. Reuse existing tokens (`text-accent-purple`, `text-fg-muted`, `border-line`, `bg-overlay-5`, `bg-overlay-8`) — do not invent colors.
- No backend, migration or `src/types/index.ts` changes.
- Every task gate: `npx tsc --noEmit` from `c:\capstsh\admin` exits 0.
- Files touched: `admin/src/features/memberships/pages/MembershipsPage.tsx`, `admin/src/features/qr/pages/QRPage.tsx`, plus one new verification script under `admin/scripts/`.

## Review Focus

- Custom range with `end <= start` must be blocked (Create disabled + inline error).
- Switching Plan Type Daily <-> Monthly must not retain a stale `custom` flag.
- Daily plan must ignore Custom entirely (duration/end date fields are monthly-only).
- Renewal panel keeps Approve/Decline wired to `handleApprove` / `handleDecline`, and mock-profile resolution intact.
- QR action buttons stay real `<button>` elements with `title` tooltips after restyling.

## File Structure

| File | Responsibility |
|---|---|
| `admin/src/features/memberships/pages/MembershipsPage.tsx` | Tabs, membership table, New Membership drawer (plan/duration/dates), renewal panel |
| `admin/src/features/qr/pages/QRPage.tsx` | QR cards, Pending + Confirmed enrollment tables, drawers |
| `admin/scripts/verify-membership-qr-ux.mjs` | Playwright evidence: screenshots + style assertions |


---

## Task 1 — Solid purple selected state (Plan Type + Duration buttons)

**Deliverable:** Daily/Monthly and the 1–6 buttons render solid `#7C3AED` with white text when selected.

- [ ] **Step 1: Restyle Plan Type buttons** — in `MembershipsPage.tsx`, replace the selected branch on both buttons:

```tsx
// Daily
form.plan_type === 'daily'
  ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
  : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
// Monthly
form.plan_type === 'monthly'
  ? 'bg-[#7C3AED] border-[#7C3AED] text-white shadow-sm'
  : 'bg-overlay-8 border-line text-fg hover:border-fg-muted'
```

- [ ] **Step 2: Restyle Duration number buttons** — same swap for `form.months === n`.
- [ ] **Step 3:** `npx tsc --noEmit` → exit 0.

## Task 2 — "Custom" duration option for Monthly (editable start/end)

**Deliverable:** a 7th "Custom" button in the duration grid; when active the End Date field becomes an editable date input, the helper text changes, and an end date not after the start date blocks Create.

- [ ] **Step 1: Extend form state** and the `openCreate` reset with `custom: false` and `end_date: addDays(todayStr(), 30)`.
- [ ] **Step 2: Honor custom when computing the end date:**

```tsx
const endDate = form.plan_type === 'monthly' && form.custom
  ? form.end_date
  : addDays(form.start_date, durationDays)
const customInvalid = form.plan_type === 'monthly' && form.custom
  && (!form.end_date || form.end_date <= form.start_date)
```

- [ ] **Step 3: Add the Custom button** after the `1..6` map, in a `grid-cols-7` grid; number buttons set `custom: false`.
- [ ] **Step 4: Make End Date editable in custom mode** — `<input type="date" min={form.start_date}>` plus the `customInvalid` message; otherwise keep the read-only auto-calculated div.
- [ ] **Step 5:** add `|| customInvalid` to the Create button's `disabled`.
- [ ] **Step 6:** both Plan Type `onClick`s clear `custom`.
- [ ] **Step 7:** `npx tsc --noEmit` → exit 0.

## Task 3 — Purple Renew button

- [ ] **Step 1:** table Actions cell →

```tsx
className="px-2.5 py-1 text-xs font-medium bg-[#7C3AED] text-white rounded-lg hover:bg-[#6D28D9] transition-colors"
```

- [ ] **Step 2:** `npx tsc --noEmit` → exit 0.

## Task 4 — Renewal panel: lines, title styling, Actions column

**Deliverable:** the Renewal tab renders the same table chrome as Daily/Monthy (header row on `bg-overlay-5` with a bottom border, `border-line-soft` row dividers, right-aligned Actions column).

- [ ] **Step 1:** replace the outer `glass-card rounded-xl p-4` + `space-y-3` row list with a titled card whose body is a `<table>` with columns Member / Plan / Requested / Actions; move the existing Approve/Decline buttons verbatim into the Actions `<td>`. Keep the `pendingList.length > 0 ? ... : ...` wrapper and the mock/dismiss logic untouched.
- [ ] **Step 2:** `npx tsc --noEmit` → exit 0.

## Task 5 — Visible action buttons on QR Pending

- [ ] **Step 1:** wrap the three icon buttons in `<div className="flex items-center justify-end gap-1.5">` and give each a bordered, tinted chip:

```tsx
// View      → border-[#7C3AED]/40 bg-[#7C3AED]/15 text-accent-purple hover:bg-[#7C3AED] hover:text-white
// Confirm   → border-emerald-500/40 bg-emerald-500/15 text-emerald-500 hover:bg-emerald-500 hover:text-white
// Reject    → border-rose-500/40 bg-rose-500/15 text-rose-500 hover:bg-rose-500 hover:text-white
```

Keep `openView` / `handleConfirm` / `handleReject` and the `title` attributes.

- [ ] **Step 2:** `npx tsc --noEmit` → exit 0.

## Task 6 — Full verification

- [ ] **Step 1:** `npx tsc --noEmit` → exit 0.
- [ ] **Step 2:** `npm run build` → succeeds.
- [ ] **Step 3:** write `admin/scripts/verify-membership-qr-ux.mjs` (Playwright, msedge channel, same login helper pattern as `verify-login-swap.mjs`) that screenshots the four states and asserts: Custom button present + end date editable + summary updates; Renewal header contains an `Actions` `th`; Renew button computed background is `rgb(124, 58, 237)`; QR action buttons have non-transparent backgrounds.
- [ ] **Step 4:** run it → all assertions pass; review screenshots in `admin/screenshots/membership-qr-ux/`.
- [ ] **Step 5:** commit the two components + script (+ screenshots, matching the existing `admin/screenshots/` convention).

## Self-Review Notes

- Request 1 → Tasks 1 and 2. Request 2 (Renew button) → Task 3. Request 3 (renewal lines/title/action) → Task 4. Request 4 (QR visibility) → Task 5.
- Assumptions: "Custom" appears only under Monthly (Daily is a fixed 1 day); the start date was already editable so Custom makes the end date editable; "put an action there" means an Actions column header above the existing Approve/Decline buttons.
