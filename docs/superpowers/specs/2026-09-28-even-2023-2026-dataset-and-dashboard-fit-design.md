# Even 2023-2026 Demo Dataset + Dashboard Table Fit (Admin)

**Date:** 2026-09-28
**Scope:** `admin/` only. `ai-service/*`, `chapter123/*` and `admin/server/index.js` are out of scope and untouched.

## 1. Problem

Selecting **All time** on the dashboard leaves four of the five tabs showing `0` with
`Loading...`, because every non-Revenue tab downloads the entire `attendance` table into
the browser to compute its KPIs and trend chart.

Measured against the live database during planning:

| Probe | Result |
| --- | --- |
| `fetchAttendance` for 2023-01-01 to today | 38,101 rows / 39 sequential pages / **16.1 s** |
| Cost of one deep-offset page | 438-625 ms |
| Attendance row count by year | 2020: 737, 2021: 1,257, 2022: 2,046, 2023: 3,027, 2024: 4,256, 2025: 5,609, **2026: 25,209** |
| Attendance by month | 2026-06: 533; **2026-07: 5,061; 2026-08: 5,650; 2026-09: 6,187** |
| Memberships by `start_date` year | 2020-2025: 114 total; **2026: 1,746 of 1,860** |
| Sundays | 0 rows (gym closed) |
| `member_last_checkin()` | `content-range 0-999/1047` - PostgREST caps it, so **47 members have no last check-in** |
| Migration 0035 | already applied (the RPC answers) |

The KPI cards compound the problem by rendering `0` (not a placeholder) while
`isLoading`, so a 16-second wait reads as broken data rather than work in progress.

Separately, every tab's bottom list renders a fixed ten rows into a container that only
fits about three. The third row is sliced in half and three nested scroll containers
(`overflow-auto` + `overflow-x-auto` inside a `min-h-0` flex child) mean the cut row has
no visible scrollbar to explain it.

## 2. Desired outcome

The dataset covers **2023-01-01 through today** and is spread **evenly across every month
in that window**, so no year or month reads as empty and no single quarter owns most of
the data. Every dashboard tab shows correct, non-zero figures for *All time* in a couple
of seconds, and every list shows whole rows with a real total.

## 3. Constraints and non-goals

- Admin web app only. No mobile, no AI service, no API server changes.
- Business rules that must survive: the gym is closed on Sundays; today carries exactly
  3-4 open check-in sessions and never a session in the future; the roster stays at
  987 members / 89 trainers / 1 admin; profiles and their `Mxxx` / `Txxx` codes are never
deleted or renumbered.
- Budgets that must survive exactly: 10 pending + 45 confirmed enrollments; 24 pending +
  150 approved + 36 declined renewals; 320 retention + 26 weight predictions; 60 trial
  memberships; 9 notification titles.
- The retention model in `ai-service/services/ml.py` scores a member from their **last 30
  check-ins**, so the low/medium/high risk bands require a cohort of members who train
  3-7 times a week **recently**. This is the one deliberate exception to a flat
  distribution (see 4.2).
- Non-goal: replacing the dashboard with server-side aggregate RPCs. Documented as a
  future option in 7.

## 4. Design

### 4.1 One window, one source of truth

`DATA_START = 2023-01-01` and `DATA_END = today` are declared once in the seed library and
consumed by the admin app. They replace three separate hardcoded values: the `All time`
range start in `dateRange.ts` (was `2020-01-01`), the day-index epoch in `attendance.mjs`
(was `Date.UTC(2020, 0, 0)`) and `START_MS` in `users.mjs`. The date picker's minimum
becomes `DATA_START` so no user can request a window the data does not cover.

The window is 1,367 days: 1,172 Mon-Sat open days and 195 closed Sundays.

### 4.2 Even distribution per table

| Table | Today | After | Method |
| --- | --- | --- | --- |
| `attendance` | 42,141 rows, 60% in 2026 | ~12,900 | flat 9 per open day (10,548) + ~2,300 recent-cohort rows |
| `memberships` | 1,746 of 1,860 start in 2026 | ~2,100 | monthly sales quota of ~25 across the window |
| `profiles.created_at` | spread 2020-2026 | ~22 joins/month | `joinedAt` uniform over the window |
| `membership_renewal_requests` | clustered | 24 recent + 186 spread | spread `requested_at` / `decided_at` |
| `notifications` | clustered | spread | spread `created_at`, 9 titles kept |
| `predictions` | 180-day review window | spread over the window | `REVIEW_DAYS` -> window length |
| `trainer_assignments`, `trainer_feedback` | clustered near today | spread | spread `assigned_at` / `created_at` |
| `enrollments` | 10 pending + 45 confirmed | 10 recent + 45 spread | spread `created_at` of decided rows |

Flat attendance volume replaces the old ramp `k = 2 + 22 * t^1.6`, which is what made the
early years nearly empty (3/day in 2020) and 2026 heavy (24/day plus the overlay).

**The documented exception.** The old overlay trains 330 members at 3-7 sessions a week
over the last 12 weeks, which is ~19,000 of the 2026 rows. Spreading that cohort evenly
across four years would be roughly 700,000 rows, so the overlay stays recent but shrinks
to about 2,300 rows over the final eight weeks. The trade-off is explicit: the last three
months run about 3x the baseline instead of today's 12x. Removing the overlay entirely
would give a perfectly flat line at the cost of the Predictions page losing its low and
medium risk bands.

Memberships keep one base row per member (so the active/expired/trial mix and the
renewals queue still work) but replace "walk history backwards from today" with a monthly
quota, which is what puts sales - and therefore revenue - in every month.

### 4.3 Making All time load

1. **Parallel paging.** `fetchAll.ts` issues one `count: exact` request to size the run,
   then fetches four pages at a time with a single retry (the seed proves concurrency 4 is
   safe; the observed PostgREST 500s started at 12). 13 pages become ~4 batches, about 2 s.
2. **Fix the last-check-in aggregate.** Migration 0036 adds `p_limit` / `p_offset` to
   `member_last_checkin` and `fetchLastCheckins` pages it. Range headers are ignored on
   RPC, so parameters are the only way to see all 1,047 rows.
3. **Honest loading states.** `KpiCard` gains `isLoading` and renders a shimmer plus an
   em dash instead of a false `0`; the chart and table cards show "Loading history, page 4
   of 13"; and a range change keeps the previous data on screen instead of blanking.

### 4.4 Layout: the cut-data fix

The chart card currently competes with the table card for the leftover height (`flex-1`
on both), so each gets about half and the table ends up with room for three rows.

- The chart gets a **bounded height** (~240 px) and the table absorbs the remainder
  (`flex-1`, `min-h-[16rem]`).
- `RecordsTable` derives its page size from a **measured** `useFitRows`, so a full page
  fits by construction and no row is ever half drawn.
- One scroll container instead of three nested ones, a sticky `thead`, and a footer that
  is always present and always reports a real range (`1-9 of 1,207`).
- `BarTrend` gains `maxBarSize` and adaptive axis labels, which also fixes the single
  full-width bar that a one-day range currently draws.
- Numeric columns use `tabular-nums`, long names and plan labels truncate with a tooltip.

## 5. Success criteria

1. All five tabs at *All time* settle with non-zero KPIs equal to a service-role
   recomputation, in 3 seconds or less, and never flash a false zero.
2. Zero clipped rows on every tab at 1920x1080, 1366x768 and 1024x768, each with a real
   pager total.
3. Every month from 2023-01 to 2026-09 contains attendance rows and membership sales;
   max/min monthly volume stays within about 60%.
4. All exact budgets in 3 hold, `member_last_checkin` returns all 1,047 rows, and
   `npm run build`, `verify-demo-data`, `verify-dashboard-tabs`, `verify-admin-ui`,
   `verify-dataset-spread` and `tsc --noEmit` all pass.

## 6. Risks

- **PostgREST 500s under concurrency.** Mitigation: concurrency 4, one retry, page count
  from the count query so a failed batch cannot silently shorten the dataset.
- **Re-seeding changes expected counts.** `verify-dashboard-tabs.mjs` recomputes its
  expectations from the service role; any remaining literals move to the same pattern.
- **Purge safety.** The reset script deletes only rows whose id carries a seed prefix and
  never touches `profiles`.
- **Code stability.** Profiles are re-anchored (dates only), never deleted, so `Mxxx` and
  `Txxx` codes keep their meaning.

## 7. Future option (not in this plan)

If "All time" must stay under a second as the dataset grows, the dashboard can move onto
server-side aggregate RPCs (daily attendance counts, daily revenue, monthly growth,
per-type activity counts, member overview) plus server-side paging for the five lists,
reusing the existing `pagedTable.ts` pattern. Est. 4 extra tasks and migration 0036.
