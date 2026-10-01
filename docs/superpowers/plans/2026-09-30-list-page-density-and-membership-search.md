# Admin List Pages: 15 Rows Per Page, No Scroll, Search On Every Membership Tab

> **Goal:** The Members, Trainers and Memberships pages each show exactly 15 rows per page, all 15 visible with no scrollbar, the rest overleaf. On Memberships, the search box moves above the Daily/Monthly/Renewal tabs, works on all three, the member's code gets its own column, and the "Start date" button is gone.

- **Architecture:** The page size is a **pinned contract** (`LIST_PAGE_SIZE = 15` in `lib/listHooks.ts`) and the **row height is measured** (`useFitRowHeight` in `hooks/useFitRows.ts`, plus a self-measuring cell padding in `PeopleTable`). This is the inverse of the previous arrangement and that inversion is the whole fix. All three pages render the one shared `PeopleTable`; the memberships table, which had drifted into a third bespoke copy, was folded back into it.
- **Tech Stack:** React 18, Vite, TanStack Query v5, Tailwind CSS, PostgREST/Supabase, Playwright.

---

## Why it scrolled

`PAGE_SIZE = 25` on all three pages, and `useFitRows` measured **how many rows fit** (~14) and printed that as "showing 14 per view" next to a footer promising "1–25 of 987". The other 11 rows were reachable only through a scrollbar on the card body.

A page size that is a function of the window height cannot be a promise. So it was turned around: the **count** is fixed at 15, and the **height of one row** is what gives.

## Two things measurement alone did not solve

Both were found by measuring the rendered page, not by reading the code:

1. **A table row's `height` is a minimum, not a maximum.** Pinning 41px on a row whose cells wanted 12px of padding plus a 20px line box renders 45px, and the scrollbar comes back. A fixed padding ladder (`py-3`/`py-2`/`py-1.5`) cannot fix this because it assumes every row holds one line of text - a trainer row holds a 28px avatar, a renewal row a 28px action button. `PeopleTable` now measures the tallest thing actually in the first row and gives the remainder to padding, so a row occupies exactly the height it was asked for whatever it contains.
2. **The row's own 1px rule is part of its height.** Leaving it out cost one pixel per row: fifteen pixels, and one scrollbar per page.

Residual overflow after both fixes, before the renewal buttons were dropped from `py-1.5` to `py-1`: 10–12px at 1920x947, 9–39px at 1366x768. After: **0px on all five views at both viewports.**

## Plan Checklist

### Phase 1: The page size
- [x] **Task 1: `LIST_PAGE_SIZE = 15`** in `lib/listHooks.ts`, documented as a pinned contract rather than a measurement.
- [x] **Task 2: `useFitRowHeight`** in `hooks/useFitRows.ts` - the inverse of `useFitRows`, sharing its measure/observer/poll plumbing through one internal `useMeasure`. `useFitRows` itself is unchanged in behaviour and still drives the dashboard's `RecordsTable`.
- [x] **Task 3: `PeopleTable` takes `rowHeight`** and derives its cell padding from the row's real content. The header strip was slimmed from `py-3` to `py-2` to give the rows back 16px.

### Phase 2: The three pages
- [x] **Task 4: Members and Trainers** - `LIST_PAGE_SIZE` + `useFitRowHeight`, and the contradictory "showing 14 per view" line replaced by a plain total.
- [x] **Task 5: Memberships folded into `PeopleTable`** - the Daily/Monthly table was a third hand-rolled copy of the members table, with its own 420px scroll cap.
- [x] **Task 6: Search above the tabs, on all three.** The toolbar was rendered only when the Renewal tab was *inactive*, which is exactly why that tab had no search box; it is now unconditional and the term is one piece of state - Daily/Monthly resolve it to member ids server-side, the Renewal queue filters its 24 rows in memory. The "Start date" button is removed: the tabs already are that filter, and it cost a row of chrome above a 15-row table. Members keeps "Joined" and Trainers keeps "Hired" - the request was scoped to the memberships page.
- [x] **Task 7: The code gets its own column** on all three tabs and in the request panel. It used to be printed inside the name cell, so name and code shared a line and the code could not be picked out of a column of names.
- [x] **Task 8: The Renewal queue is paged like the rest** (24 rows, 15 + 9) and its rows are one line: the member's email rides along as the name's tooltip and their note as the plan cell's, because a variable-height row cannot be part of a fixed fifteen-row page. Clicking the row opens the full request panel, so nothing became unreachable.

### Phase 3: Gates
- [x] **Task 9: `verify-admin-ui` extended** - 55 checks to **67 passed / 0 failed**. New: exactly 15 rows on page 1, a table body that does not scroll, a Code column of its own, the code absent from the name cell, the Renewal search present and narrowing (and able to empty the queue), and the queue row opening the request panel. Existing totals unchanged (987 / 89), and `verify-dashboard-tabs` still 75/0 - `useFitRows` is shared with the dashboard.
- [x] **Task 10: `npm run build`** - clean (tsc + vite, exit 0; the 1.1MB chunk warning is pre-existing).

---

## Measured

Live at 1920x947 (the reported window) and 1366x768, over Members, Trainers, Memberships Daily / Monthly / Renewal:

| view | rows | row height | table overflow |
|---|---|---|---|
| Members | 15 | 44px / 32px | 0 / 0 |
| Trainers | 15 | 44px / 32px | 0 / 0 |
| Memberships Daily | 15 | 40px / 28px | 0 / 0 |
| Memberships Monthly | 15 | 40px / 28px | 0 / 0 |
| Memberships Renewal | 15 | 40px / 28px | 0 / 0 |

Page counts changed with the page size: members 987 rows is now 66 pages (was 40), trainers 89 is 6 (was 4), Monthly 1,800 is 120 (was 72), the renewal queue 24 is 2.

Screenshots: `admin/screenshots/list-pages/`.

## Trade-offs

- Rows are 28–52px depending on the window. That is the cost of "always exactly fifteen, never a scrollbar": one of the two has to give, and the page size is the one the reader was promised.
- Below ~29px of row height the content itself (a 28px action button) stops fitting and the body scrolls a little. 1366x768 is the practical floor; nothing is clipped and the page itself never scrolls.
- The memberships date filter is gone for good, not just hidden - the list hook still accepts `from`/`to` if a caller ever wants it back.

