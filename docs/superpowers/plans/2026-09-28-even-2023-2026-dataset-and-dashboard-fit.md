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
- [~] **Task 10: `0036_member_last_checkin_paging.sql` + paged client.** DONE (code). **Re-measured 2026-10-02: 0036 IS applied and 0037 is NOT**, which inverts what this task said. Live evidence: `member_last_checkin_count()` answers 200/980, `member_last_checkin({"p_limit":1})` answers 200, and a bare `member_last_checkin({})` answers **300 PGRST203 "Could not choose the best candidate function between: public.member_last_checkin(), public.member_last_checkin(p_limit => integer, p_offset => integer)"** — 0035's zero-argument overload and 0036's defaulted two-argument one are BOTH in the database, and a call with no arguments matches both. `0037_drop_ambiguous_member_last_checkin.sql` drops the zero-argument overload and is **still unapplied** (same blocker as before: the management API rejects the service-role key with `401 JWT failed verification`, so a personal access token is required). The app is not broken by this — `attendance.ts` always passes explicit `p_limit`/`p_offset`, so the dashboard reads every member in 2 requests — but a caller that forgets the arguments gets a silent 300 and falls through to the ~100-request date-window scan. The 300 was invisible to `verify-dashboard-tabs.mjs` because its tolerance filtered on `status >= 400`; that dead tolerance has now been removed.
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
| Attendance rows | 42,141 | **13,027** (13,026 seeded + 1 showcase) |
| Attendance window | 2020-01-04 -> today | **2023-01-02 -> 2026-10-02** |
| Attendance months covered | ~78 of 78, 60% in 2026 | **46 of 46, flat region median 234/mo** |
| All time attendance fetch | 16.1 s | **0.6 s for one `fetchAll`** (the All-time *view* additionally pays for the other tabs' fetches; see Notes) |
| Memberships | 1,860 (1,746 start in 2026) | **1,860, every month has sales** |
| Profiles | 987 / 89 / 1 | **unchanged**, join dates 21-25 per month |
| Enrollments | 10 pending / 45 confirmed | **unchanged** |
| Renewals | 24 / 150 / 36 (all in the last 3 months) | **unchanged counts, 37 months** |
| Predictions | 320 risk / 26 weight | **272 risk / 26 weight**, bands high 160 / medium 102 / low 10 |
| Notifications | 841 rows, 4 months | **841 rows, 9 titles** — the 1,261 previously recorded here was **wrong: 420 of those rows were a duplicated trigger batch** (see Notes) |
| `member_last_checkin()` | 1,000 of 1,047 (capped) | **978 of 978** (below the cap; guarded; 0036 applied, 0037 pending) |

## Notes

- **Risk bands are thinner than before** (low 8, was 58) because the committed cohort had to shrink from 330 members to 44 to fit a 13k-row dataset. All three bands are still populated; widening `low` means growing the overlay and the row count with it.
- **The last ~12 weeks run ~3x the flat baseline** by design: the retention model scores a member's last 30 check-ins, so a cohort training 3-7 times a week has to exist recently or the Predictions page has no low or medium band. The spread verifier excludes exactly that window, computed from the generator's own `OVERLAY_WEEKS` / `offsetWeeks` rather than a hardcoded number.
- **`REVIEW_DAYS` stays 180** on purpose — see Task 7.
- **0036 is applied, 0037 is not** — corrected 2026-10-02; this note previously said the opposite. See Task 10 for the live probe output.
- A re-seed needs `reset-demo-data.mjs --confirm` AND the generated manifests cleared; see Task 8.

---

## 2026-10-02: Re-seed for freshness, and what it uncovered

The dataset was seeded on 2026-09-30, so on 2026-10-02 `verify-dataset-spread` failed with
`every month has attendance (missing 2026-10)` — the generator's window ends on the day it runs
(attendance `2026-09-28 → 32`, `09-29 → 35`, `09-30 → 32`, `10-01 → 0`, `10-02 → 0`), and the
verifier demands every month from `DATA_START` to today. **This is a property of the design, not a
one-off: the dataset is fresh only through its seed day, so the spread gate goes red every time the
month rolls over until a re-seed.** A cheap incremental "extend to today" path was considered and
declined in favour of the documented full re-seed.

Full sequence: `reset-demo-data.mjs --confirm` → clear the per-table manifests (keeping
`members.json` / `trainers.json`, which carry the people→profileId map `seed-attendance.mjs` needs,
and `joined-at-backup.json`) → `seed-users.mjs --verify-only` → attendance → memberships → coaching
→ enrollments. `seed-users` was skipped deliberately: profiles are never purged, the re-anchor is
already applied, and a full run is ~25 minutes of auth work. Every stage printed VERIFY PASSED.

| Figure | Before (2026-09-30 seed) | After (2026-10-02 seed) |
| --- | --- | --- |
| Attendance | 13,004 rows, to 2026-09-30 | **13,027 rows, to 2026-10-02**, 4 open sessions today |
| Notifications | 1,051 | **841** |
| Memberships | 1,860 | 1,860 (332 active / 1,468 expired / 60 trial) |
| Assignments / feedback | 1,126 / 1,054 | 1,126 / 1,061 |
| Predictions | 298 | 298 (272 risk / 26 weight) |
| Enrollments / renewals | 10+45 / 24+210 | unchanged |
| Profiles | 1,077 (987/89/1) | **unchanged** |

### 1. Every re-seed was silently duplicating the renewal notifications

`notifications` held **1,051** rows: 631 inside the `3e01a009` seed range and **420 outside it** —
exactly `2 × RENEWAL_TARGET`. Migration 0027's `AFTER INSERT` trigger writes one
`Membership Renewal Request` row per admin per renewal using a **database-generated uuid**, so those
rows are outside every seed prefix and `reset-demo-data.mjs` could never match them. A purge left
them behind, the next seeding run created another 210, and `alignAutoRenewalNotices()` re-stamped
both batches from the same `requested_at`, making them exact duplicates — 56 of them inside the
newest 400 rows the Notifications screen reads. That is the "Notifications showed one type" defect
from Task 15, re-introduced by the re-seed.

`reset-demo-data.mjs` now has a `TRIGGER_OWNED` list: those rows are matched by **title** rather than
by id, and the delete is refused if any matching row turns out to sit *inside* the seed id range
(measured 0), so the title match cannot quietly grow into deleting seed-owned rows. After the purge
the table is back to 841 = 631 seeded + 210 trigger rows.

### 2. Five latent defects in the release gate, found by running it

Both browser gates now pass — `verify-dashboard-tabs` **95/0** and `verify-admin-ui` **132/0** — but
only after five fixes to the gates themselves. They are worth recording because every one of them
fails *silently* or *misleadingly* rather than loudly, and four of the five were introduced by
`1d7b8f6`, the commit that added these checks and had never been run to green.

An early reading of these failures was wrong and is corrected here: they were first blamed on the
All-time view being slow (25 attendance requests, chart drawn at ~35 s). That measurement was taken
while a second browser was left open on the All-time dashboard, so two clients were paging the same
13k-row table at once. With a single client the All-time view loads inside the gate's budget and
every assertion holds. The database was never the problem either way — the same deep-offset query
answers offset 12000 in 1.6 s and offset 6000 in 0.36 s from the service key. The contention was
real, but it was self-inflicted, and it is exactly the kind of thing that makes a timing-sensitive
gate look like a product regression.

- **`num()` could invent a zero.** It stripped non-numeric characters and called `Number('')`, and
  `Number('')` is `0` — so a `KpiCard` still showing its loading em dash was read as a confident
  zero. That is how a correct 0.7 was reported as `shown=0`. It now returns NaN, so a value that has
  not arrived can never be believed.
- **A fixed sleep raced the one uncached fetch.** The All-time section read the panel 2.5 s after a
  range switch, and switching to All time is the only read in the run that is not already cached. It
  now polls for the chart to be drawn (`waitForChartDrawn`) and adds an explicit check
  ("the All-time growth chart is drawn, not still loading"). The helper returns a boolean instead of
  throwing, because a `locator.waitFor` that rejects aborts the whole run and takes the ~75 checks
  after it with it — which is precisely what happened on the first attempt at this fix.
- **A dead 404 tolerance.** The console gate excused a 404 on `member_last_checkin` "until migration
  0035 is applied". 0035 and 0036 are both applied, and the client always passes explicit arguments,
  so the endpoint cannot 404 — the exemption could only hide real breakage. Worth noting that it
  would not even have caught the live 300 PGRST203 (see Task 10): the filter was `status >= 400`.
  Removed rather than narrowed.
- **`verify-admin-ui` aborted on its own navigation budget.** The sweep walks 12 heavy routes in one
  page, and by the later routes the accumulated PostgREST requests pushed the next `page.goto` past
  Playwright's 30 s default — `/notifications` alone reaches `networkidle` in ~1.3 s, so this was a
  budget problem, not a page problem. Crashing there reported nothing about the routes after it.
  Raised to 60 s; no assertion was touched.
- **One assertion tested the seed's vocabulary instead of the app.** The Coach Feedback check typed a
  24-character prefix of a note and demanded *exactly one* row back. The notes come from a small
  template pool, so a prefix is shared by several rows — 3 of 1,061 after this re-seed, up from 1,054
  before it. It now asserts something stronger: the result set shrank **and every row that came back
  actually contains the typed text**, which is what pins the search to the note column rather than the
  truncated cell, and holds however many rows share the prefix.

**Not fixed, deliberately:** the gates still assume one client. Two dashboards open at once will make
the All-time view slow enough to trip the timing-sensitive checks, because each tab pages the whole
attendance table independently with no in-flight de-duplication. A single-flight dataset cache in
`attendance.ts` would fix that, but it is an app change and this was a data refresh.


