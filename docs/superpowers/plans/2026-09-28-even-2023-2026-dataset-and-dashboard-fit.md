# Even 2023-2026 Demo Dataset + Dashboard Table Fit Implementation Plan

> **Goal:** Re-seed one coherent, evenly-distributed dataset covering 2023-01-01 through today, and fix the admin dashboard so *All time* loads correct non-zero figures in a couple of seconds and no tab renders a half-cut row.

- **Architecture:** Single source of truth for the dataset window (`DATA_START` in the seed library, mirrored in `dateRange.ts` and asserted by the new spread verifier). Even distribution is enforced per table by construction (flat daily attendance, month-spread membership re-joins, code-ordered join dates) and proven from the database by `verify-dataset-spread.mjs`. Load time comes from four-way parallel PostgREST paging. The layout fix is a measured page size (`useFitRows`) plus a chart height that follows the viewport.
- **Tech Stack:** Node ESM seed scripts + Supabase JS service role, React 19, Vite, TanStack Query v5, Tailwind CSS v3.4, Recharts, PostgREST/PostgreSQL, Playwright.
- **Spec:** `docs/superpowers/specs/2026-09-28-even-2023-2026-dataset-and-dashboard-fit-design.md`

---

## Plan Checklist

### Phase 0: Baseline
- [x] **Task 1: Design spec + this plan.** DONE 2026-09-28: spec written from the measured baseline (42,141 attendance rows, 60% in 2026, All time = 38,101 rows / 39 sequential pages / 16.1 s, `member_last_checkin` truncated at 1,000 of 1,047).

### Phase 1: One Window, One Source of Truth
- [x] **Task 2: `DATA_START` / `DATA_END` in `seed/lib/common.mjs`, consumed by `dateRange.ts`.** DONE: `All time` is now `DATA_START..today`, `DateRangePicker` gets `min={DATA_START}` plus a guard on custom ranges, and the hardcoded `Date.UTC(2020,0,0)` day-index epoch in `attendance.mjs` and `START_MS` in `users.mjs` are gone. Both sides declare `2023-01-01`; `verify-dataset-spread.mjs` reads both files and fails if they drift.
- [x] **Task 3: `seed/reset-demo-data.mjs`.** DONE: purges the 8 seeded tables by id prefix only, `--dry-run` by default, `--confirm` required to delete, asserts `profiles` is untouched before and after. **Two traps found while building it:** (1) `id` is a `uuid` column and Postgres has no `uuid ~~ text` operator, so PostgREST's `like` answers `42883` — and a `head`+count query then returns **no count and no error**, which looks exactly like "0 seed rows"; the script therefore matches an exact deterministic id range (`id::text=gte.3e01a003-0000-4000-8000-000000000000`, `lte …ffffffffffff`), which does work. (2) `id::text` casts work for ordered comparison but **not** for `like`. Dry run proved 47,587 seed rows across the 8 tables with 210 hand-written showcase notifications out of reach.
- [x] **Task 4: `joinedAt` uniform + `reanchorJoinedAt()`.** DONE: `planJoinedAt()` spaces the roster evenly by CODE order, so the "codes rise with seniority" invariant `ensureProfiles()` depends on survives the move (1,076 profiles, 21-25 joins per month over 45 months). Profiles are re-anchored in place — no profile is deleted or renumbered. **The bug this task exposed:** `loadExistingProfiles()` reads `admin/screenshots/demo-data/existing-profiles.json`, not the database, so moving the profiles left the 30 hand-written showcase members claiming 2026 join dates in the seed while the database said 2023 — and attendance silently began six weeks late (2023-02-13 instead of 2023-01-02). `reanchorRoster()` now writes the new dates back into that file too.

### Phase 2: Even Distribution
- [x] **Task 5: Flat attendance + retuned overlay.** DONE: `FLAT_DAILY_SESSIONS = 9` per open day replaces the `2 + 22*t^1.6` ramp, capped by the eligible pool so the first days of the window cannot log more visitors than have joined. Result: **12,974 rows, 2023-01-02 -> 2026-09-28, zero Sundays, zero future check-ins, 3 open sessions today.** The overlay shrinks from 330 members to 44 and stays inside the last 12 weeks (**2,540 rows**), the documented exception. **A pre-existing bug surfaced here:** the overlay's weekly quota was `v < tier.visitsPerWeek` regardless of how many open days the week had, so on a 1-day week every member stacked their whole week onto today — 177 sessions on the demo "today" (it would have been ~1,200 with the old cohort). The quota is now `min(visitsPerWeek, openDays.length)`, which also keeps the 7/wk tier's double-day wrap intact.
- [x] **Task 6: Month-spread membership sales.** DONE: history blocks are placed in distinct MONTHS between the join date and the base (a re-join after a lapse) instead of packed contiguously backwards from the base, which is what put 94% of all sales in the final year. Every one of the 45 months now has sales, and the row budget is unchanged at 1,860 (60 Daily / 1,800 Monthly / 60 trials) rather than the 2,100 first estimated. Side effect of the flat attendance: fewer members have a check-in inside the 45-day lapse window, so active memberships are **328** (not the 645 first estimated) — still well above the 210 the renewals queue needs, and the expiring panels get 70 rows at <=7d and 307 at <=30d.
- [x] **Task 7: Spread the other five tables.** DONE: renewal requests keep the pending 24 anchored to current memberships (live work) while decided ones are drawn from the whole membership history, so 210 renewals cover 37 months instead of the last three; enrollments spread their 45 confirmed rows across the window while the 10 pending stay in the live queue; notifications age the older rows across the whole window while the newest 50 stay fresh so the list still shows a mix. **Predictions deliberately keeps `REVIEW_DAYS = 180`**: that page reads the newest 50 rows and renders TWO metrics, and stretching the review window over 3.7 years pushes every weight row out of view again — the exact defect an earlier task fixed. The comment now says so.
- [x] **Task 8: Re-seed the live database + verifiers.** DONE: purge -> seed-users (re-anchor) -> attendance -> memberships -> coaching -> enrollments, all green. `verify-dataset-spread.mjs` (new) reads the DATABASE, not the generator, and asserts month coverage, the flat-region variance, no rows before the window, no Sunday sessions, no future dates, and that seed/app `DATA_START` agree: **all checks pass**, attendance flat region 1.32x max/min over 36 months. **The trap that made the first two re-seeds no-ops:** `upsertChunks` uses `ignoreDuplicates: true`, which is `ON CONFLICT DO NOTHING` — re-seeding over existing rows never updates them, so new data silently merged with old. Each table's manifest also checkpoints `inserted`, so a resumed run inserts nothing. A re-seed therefore needs the purge first, and the generated manifests cleared.

### Phase 3: Make All Time Load
- [x] **Task 9: Parallel paging in `fetchAll.ts`.** DONE: four pages in flight, one retry per page, speculative batching instead of a count query (saves a round trip and needs no call-site changes; costs at most 3 empty requests at the tail), pages stitched back in offset order. **Measured against the live API on the All time attendance fetch: 2,695 ms sequential -> 617 ms, 4.4x, with all 12,974 rows unique and in order.** Combined with the smaller dataset that is the 16 s -> ~0.6 s change.
- [~] **Task 10: `0036_member_last_checkin_paging.sql` + paged client.** DONE (code), **NOT APPLIED**: the migration is written with `p_limit`/`p_offset` (defaults keep the 0035 zero-argument call working) plus a `member_last_checkin_count()`, but it cannot be applied from here — the Supabase management API rejects the service-role key with `401 JWT failed verification`, so a personal access token is required. Re-measured on the new dataset, the RPC returns **986 of 986** rows, so the bug is latent rather than active. The client is now guarded regardless: a response of exactly `PAGE` rows is treated as truncated and falls through to the paged read, which costs ~0.6 s now instead of the ~29 s it cost when written.
- [x] **Task 11: Honest loading states.** DONE: `KpiCard` takes `isLoading` and renders an em dash + pulsing bar + `aria-busy` instead of a confident `0` — all 20 dashboard cards are wired. All five hooks use `placeholderData: keepPreviousData`, so a range change keeps the previous figures on screen instead of blanking to zeros. The stale 404 tolerance for the 0035 RPC is gone from `verify-admin-ui.mjs`, and the gate still passes, which proves the RPC is really there. Dropped from the plan: a "page n of m" progress readout — at ~0.6 s a page counter would only flicker, and the shimmer already says "working".

### Phase 4: The Cut-Data Fix
- [x] **Task 12: `RecordsTable` redesign.** DONE: the page size is MEASURED with `useFitRows` instead of hardcoded at 10, so a full page is a whole page by construction; three nested scrollers (`overflow-auto` + `overflow-x-auto` + a flex child) collapsed into one; `thead` is sticky; the footer is ALWAYS rendered with a real `Showing 1-9 of 12,974 records` range; the index column and ranges use `tabular-nums`; long values truncate at 22rem.
- [x] **Task 13: Chart/table height balance.** DONE: the chart box height follows the VIEWPORT (`h-[84px]` up to `h-[200px]` via arbitrary media variants) instead of splitting 50/50 with the table. **The obvious fix made things worse first:** a fixed 200px chart plus a 16rem table floor overflowed a 768px viewport by ~101px, which the release gate reported as clipping. The table floor is now 6rem and the minimum fitted page size 2 rows, and the chart shrinks on short windows.
- [x] **Task 14: All gates.** DONE 2026-09-28, all green:
  - `npm run build` — clean, 2,509 modules, 6.3 s (the 1.1 MB chunk warning is pre-existing).
  - `tsc --noEmit` — clean.
  - `verify-demo-data` — ground truth refreshed: attendance 12,974 (2023-01-02 -> 2026-09-28), memberships 1,860, assignments 1,126, feedback 1,054, predictions 296, notifications 1,261, enrollments 10/55, renewals 24/210, profiles 987/89/1.
  - `verify-dataset-spread` — **all checks pass** (45/45 months, flat region 1.32x, nothing before 2023-01-01, no Sundays, no future rows).
  - `verify-dashboard-tabs` — **75 passed / 0 failed / 0 skipped** across 5 tabs x 7 viewports (1920x1080 -> 1024x768), zero clipping everywhere.
  - `verify-admin-ui` — **55 passed / 0 failed / 0 skipped** over 12 routes x 3 viewports, with the RPC 404 exemption removed.
  - **One gate bug found and fixed:** `verify-dashboard-tabs.mjs` computed its membership-filter ground truth from an UNORDERED fetch while `resolvePlan()` falls back to "the last row of this member's rows". That agreed by luck while memberships were contiguous, and started disagreeing once the seed gave members spaced re-join history (where most check-ins take that fallback). The ground truth is now ordered `start_date, id`, exactly as the app fetches it.

---

## Ground Truth: Before -> After

| Figure | Before | After |
| --- | --- | --- |
| Attendance rows | 42,141 | **12,974** |
| Attendance window | 2020-01-04 -> today | **2023-01-02 -> 2026-09-28** |
| Attendance months covered | ~78 of 78, 60% in 2026 | **45 of 45, flat region 1.32x** |
| All time attendance fetch | 16.1 s | **0.6 s** |
| Memberships | 1,860 (1,746 start in 2026) | **1,860, every month has sales** |
| Profiles | 987 / 89 / 1 | **unchanged**, join dates 21-25 per month |
| Enrollments | 10 pending / 45 confirmed | **unchanged** |
| Renewals | 24 / 150 / 36 (all in the last 3 months) | **unchanged counts, 37 months** |
| Predictions | 320 risk / 26 weight | **270 risk / 26 weight**, bands high 160 / medium 102 / low 8 |
| Notifications | 841 rows, 4 months | **1,261 rows, 45 months, 9 titles** |
| `member_last_checkin()` | 1,000 of 1,047 (capped) | **986 of 986** (below the cap; guarded, 0036 pending) |

## Notes

- **Risk bands are thinner than before** (low 8, was 58) because the committed cohort had to shrink from 330 members to 44 to fit a 13k-row dataset. All three bands are still populated; widening `low` means growing the overlay and the row count with it.
- **The last ~12 weeks run ~3x the flat baseline** by design: the retention model scores a member's last 30 check-ins, so a cohort training 3-7 times a week has to exist recently or the Predictions page has no low or medium band. The spread verifier excludes exactly that window, computed from the generator's own `OVERLAY_WEEKS` / `offsetWeeks` rather than a hardcoded number.
- **`REVIEW_DAYS` stays 180** on purpose — see Task 7.
- **Migration 0036 is written but unapplied** — see Task 10.
- A re-seed needs `reset-demo-data.mjs --confirm` AND the generated manifests cleared; see Task 8.
