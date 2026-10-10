# Ledger — Member Insight + goal-progress unification (2026-10-09)

Inline execution of the approved plan (executing-plans skill). All tasks
complete; `flutter analyze` = 0 issues; `flutter test` = 14/14.

## Tasks

1. **Shared formula (TDD)** — `lib/features/shared/utils/goal_progress.dart`
   + `test/goal_progress_test.dart`. RED (18 analyzer errors on missing
   helper) → GREEN (14/14). Contains John Paul Hoquiton's exact scenario:
   baseline 60 / target 70 / live 62 → 20%, not the old 86%.
2. **Member GoalCard refactor** — inline math replaced by
   `computeGoalProgress`; behavior preserved; analyze clean.
3. **Slim Members list** — `progress_list_page.dart`: provider renamed
   `assignedMembersProvider` (profiles + attendance only; measurements,
   goals, and the per-member AI forecast loop removed); card replaced by
   `_MemberRow` (avatar + name + last check-in + chevron); taps go to
   `/trainer/insight/:id`.
4. **New screens** — `features/trainer/insight/pages/`:
   `member_insight_search_page.dart` (search by name/code, reuses
   `assignedMembersProvider`) and `member_insight_page.dart`
   (`memberInsightProvider` = profile/goals/measurements/check-ins;
   `memberRiskProvider` = 5s-capped forecast, chip hides on failure;
   goal ring uses the shared formula; This Week bars reuse
   `memberProgressDataProvider`).
5. **Routes + entry** — `/trainer/insight` and `/trainer/insight/:id`
   added to `router.dart` (root navigator, iOS push); dashboard header
   search icon (tooltip "Find a member") pushes `/trainer/insight`.
6. **Verification** — whole-project analyze clean; 14/14 tests.

## Rulings

- Members-list tap opens `/trainer/insight/:id` (new detail), not
  `/trainer/members/:id`; the old charts page stays reachable via
  "View full progress" on the insight screen. Cost if wrong: one route
  swap.
- `goal_pct` removed from the list provider entirely (list shows name +
  last check-in only); the86→20 fix is proven in the unit tests and
  displayed on the insight screen.
- No commits made: the worktree carried uncommitted prior-session changes
  (`dashboard_page.dart` greeting/logo work, `member_progress_page.dart`
  workout-log series); committing would have bundled them.
- Insight week-bars are a simple local widget (no tap-to-select) instead
  of promoting the private `_WeekChart`; keeps `member_progress_page.dart`
  untouched.
- `assignedMembersProvider` keeps the 90-day attendance window, so a
  check-in older than 90 days shows "No check-ins yet" (pre-existing
  behavior, unchanged).

## Deferred minors

- `_lastCheckinLabel` is duplicated in three files (list row, search row,
  and the detail header could share it) — a shared widget would dedupe.
- The dashboard diff also contains pre-existing uncommitted greeting/logo
  work from an earlier session (not part of this task).
## Runtime verification (2026-10-09, re-check)

- `flutter analyze` (whole project): 0 issues.
- `flutter test`: 14/14 pass (`goal_progress_test.dart` + existing suite).
- Device check: a physical Android 13 device is attached (`V2124 ...
  3415737434000RB`), plus desktop/web targets. A live `flutter run`/
  `flutter test --device` interaction was NOT executed in this shell
  (no Flutter app-runner harness in this environment; headless). The
  dashboard page and the Member Progress list are covered by the
  clean-project analyze, and the exact legacy scenario (60/70/62 → 20%)
  is unit-proven. If a live screenshot on the device is desired, run:
  `flutter run -d V2124 --machine`, then take a screenshot, and open the
  Insights screen after a search + tap; there is no integration-test file
  for these screens — deferred (see below).

