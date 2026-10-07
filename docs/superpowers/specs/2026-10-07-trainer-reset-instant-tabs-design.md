# Trainer Reassignment Reset + Instant Trainer Tabs — Design Spec

Date: 2026-10-07
Status: approved design, awaiting spec review
Scope: trainer reassignment semantics (feedback + chat reset), trainer tab performance, members search, trainer conversations list.

## 1. Shared understanding

Intended outcome: after an admin moves a member to a new trainer,
- the member's Feedback page shows ONLY the current trainer's feedback (old rows stay in DB, hidden from member), and new feedback appears immediately;
- the member's chat with the new trainer starts EMPTY (pre-assignment messages hidden, not deleted);
- trainer Dashboard / Members / Chat / Profile feel instant on tab switch;
- Members tab has a search box (name + member code);
- Trainer Conversations lists ALL actively assigned members.

Constraints: Flutter + Riverpod + Supabase patterns in repo; hide-not-delete; no schema migration; admin API fix where root cause demands it.

Verified facts (M002/T002) driving the design:
- M002 assigned to T002 (active since Oct 4); old trainer T057 ended.
- New T002 feedback exists but member page shows old T057 rows: stale keep-alive cache + no trainer filter.
- M002-T002 chat room created Aug 15, BEFORE the Oct 4 assignment: old messages predate it.
- /api/assign-trainer only inserts, never ends old rows: two active rows make member limit(1) resolve the old trainer.
- T002 has 12 active assignments but 1 chat_rooms row: rooms exist only after first member message.

## 2. Design A — member feedback reset + freshness
1. trainerFeedbackProvider resolves the active assignment FIRST (status=active, order assigned_at desc, limit 1), then filters trainer_feedback by that trainer_id. No active trainer = friendly empty state.
2. Refresh-on-open via routerDelegate listener (home_page.dart pattern): cached data renders instantly while refetching.
## 3. Design B — chat reset on reassignment (hide, not delete)
1. Member chat provider: deterministic active-assignment pick (order assigned_at desc, limit 1), carry assigned_at alongside trainerId.
2. Message fetch keeps only created_at >= assigned_at (client-side filter, no migration; same code path both sides).
3. Trainer chat room page: resolve active assignment for the (trainer, member) pair the same way, apply the same date filter. Both sides always agree.
4. Admin /api/assign-trainer: before insert, end all other active assignments for that member (status=ended, ended_at=now). Kills the two-active-trainers bug at the root. Unassign endpoint unchanged.

## 4. Design C — instant trainer tabs
1. TrainerShell (app/router.dart): ShellRoute to StatefulShellRoute.indexedStack mirroring MemberShell. Pages stay alive; switches instant after first visit. Same 5 destinations; _trainerIndex mapping preserved via branch index.
2. Members tab (progress_list_page.dart, the page actually rendered at /trainer/members): drop autoDispose + initState self-invalidate; replace per-member measurement+goal loop (2xN queries) with two batched inFilter(member_id, memberIds) queries in parallel with profiles (3 round trips). Add user-scoping guard like homeDataProvider.
3. Dashboard provider: Future.wait parallel waves after memberIds known. Same return shape; UI untouched.
4. Chat list provider: replaced by design D (assignments + rooms in parallel, embedded profiles, no N+1 loop).
5. Cache policy: keep-alive (not autoDispose) for all four tab providers + router-listener refresh-on-return, so revisits render cached data instantly while refetching.

## 5. Design D — conversations = assigned members
1. New trainerConversationsProvider: parallel fetch of (a) active assignments with embedded member profile, (b) trainer chat_rooms. Merge: one row per assigned member; room attached when pair matches; rooms of non-assigned members excluded.
2. Roomless row shows 'Tap to open conversation'; tap creates room on demand then pushes ChatRoomPage. Rows with rooms push directly.

## 6. Design E — members search box
1. Search field at top of progress_list_page.dart, client-side filter on full_name (case-insensitive) + profile code (e.g. M002). Clear (x) button; 'No members match' empty state.
2. Add code to the profiles select (currently id/full_name/avatar_url only).

## 7. Files to change (for the plan step)
- mobile app/router.dart (TrainerShell), trainer dashboard_page.dart, trainer progress_list_page.dart, trainer chat_list_page.dart (+ conversations provider), trainer chat_room_page.dart, member feedback_page.dart, member chat_page.dart, shared feedback_service.dart, optionally shared chat_service.dart room-creation helper.
- admin server/index.js /api/assign-trainer. No DB migration.

## 8. Verification
- M002 scenario: member Feedback shows only T002 rows; new feedback appears on revisit; member chat with T002 empty; trainer room agrees.
- Trainer tabs: cold-load once each, then switches instant with background refetch.
- Members search filters on name/code; clear restores.
- T002 Conversations shows 12 rows; tapping roomless member creates + opens room.
- flutter analyze clean; assign-trainer leaves exactly one active row per member.

