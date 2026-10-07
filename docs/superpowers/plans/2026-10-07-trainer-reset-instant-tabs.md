# Trainer Reset + Instant Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After an admin reassigns a member, the member app shows only the current trainer's feedback and an empty chat; trainer tabs switch instantly; members tab is searchable; conversations list every assigned member.

**Architecture:** Scope by assignment boundary: member queries resolve the single active assignment (ordered by assigned_at desc) and filter by it; messages hide (never delete) anything predating the assignment; admin assign closes old rows; trainer tabs become keep-alive indexed-stack branches with batched parallel queries.

**Tech Stack:** Flutter, Riverpod FutureProvider, go_router StatefulShellRoute.indexedStack, Supabase PostgREST, Express admin API.

**Spec:** docs/superpowers/specs/2026-10-07-trainer-reset-instant-tabs-design.md

## File map

| File | Responsibility |
|---|---|
| admin/server/index.js | assign-trainer ends old active rows before insert |
| shared feedback_service.dart | optional trainerId filter |
| member feedback_page.dart | assignment-scoped provider + refresh on return |
| member chat_page.dart | deterministic assignment + assigned_at date filter |
| trainer chat_room_page.dart | same date filter trainer side |
| app/router.dart | TrainerShell to indexedStack |
| trainer dashboard_page.dart | parallel waves, keep-alive |
| trainer progress_list_page.dart | batched queries + search box |
| trainer chat_list_page.dart | conversations-from-assignments + on-demand rooms |

## Phase A — admin assign closes old rows

No test framework in admin/server; verify via Supabase dashboard.

- [ ] **Step 1: patch /api/assign-trainer to end prior rows**

In `admin/server/index.js`, inside the try block BEFORE the insert, add:

```js
const { error: endError } = await adminClient
  .from('trainer_assignments')
  .update({ status: 'ended', ended_at: new Date().toISOString() })
  .eq('member_id', member_id)
  .eq('status', 'active')
if (endError) throw endError
```

Keep the insert and 23505 conflict branch unchanged. Keep unassign unchanged.

- [ ] **Step 2: verify one-active-row invariant**

Assign a test member to two trainers via the admin UI; in Supabase confirm exactly one `status=active` row remains and both rows still exist.

- [ ] **Step 3: commit**

## Phase B — member feedback reset + freshness

- [ ] **Step 1: optional trainerId filter on getFeedbackWithTrainer**

In `mobile/shared/lib/services/feedback_service.dart`, change the signature to accept `String? trainerId` and apply `.eq('trainer_id', trainerId)` when non-null, before the `.order`. If the analyzer complains about builder reassignment, type the intermediate as `dynamic`.

- [ ] **Step 2: scope trainerFeedbackProvider to active assignment**

In `mobile/fitness_app/lib/features/member/feedback/pages/feedback_page.dart` replace the provider body with: fetch active assignment (eq member_id, eq status active, order assigned_at desc, limit 1); empty means return `[]`; else call `FeedbackService().getFeedbackWithTrainer(userId, trainerId: trainerId)`. FeedbackService import already exists in that file — do not duplicate.

- [ ] **Step 3: refresh on return (cached-first)**

In `_FeedbackPageState`: add `import 'package:go_router/go_router.dart';`, add `_router`/`_wasFeedback` fields, register a routerDelegate listener in `didChangeDependencies` that invalidates `trainerFeedbackProvider` when the path becomes `/member/feedback` after being elsewhere, and remove the listener in `dispose`. Keep existing rate/comment invalidations.

- [ ] **Step 4: verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze lib/features/member/feedback/pages/feedback_page.dart
```

Manual as M002: Feedback shows only T002 rows; new T002 feedback appears via notification without restart; member with no trainer sees empty state.

- [ ] **Step 5: commit (Phase B)**

```bash
git add mobile/shared/lib/services/feedback_service.dart mobile/fitness_app/lib/features/member/feedback/pages/feedback_page.dart
git commit -m "fix(member): feedback scoped to active trainer, refresh on return"
```

- [ ] **Step 3: commit (Phase A)**

```bash
git add admin/server/index.js
git commit -m "fix(admin): assign-trainer ends prior active rows"
```

## Phase C — chat reset both sides (hide, not delete)

- [ ] **Step 1: member chat provider carries assigned_at**

In `mobile/fitness_app/lib/features/member/chat/pages/chat_page.dart`, in `trainerChatProvider`: change the assignment select to `'trainer_id, assigned_at'` plus `.order('assigned_at', ascending: false)`; return map gains `'assignedAt': assignment[0]['assigned_at'] as String?`.

- [ ] **Step 2: member message load filters by assigned_at**

In `_loadMessages` (same file): after fetching messages, parse `assignedAt` passed via provider (store in a `_assignedAt` field set in `_initChat`); drop any message with `created_at` before it (compare with `DateTime.parse(...).isBefore`). Keep realtime `_subscribe` as-is (it reloads through the same filter).

- [ ] **Step 3: trainer room page applies the same filter**

In `mobile/fitness_app/lib/features/trainer/chat/pages/chat_room_page.dart` `_loadMessages`: after loading the room's participants, fetch the active assignment for that (trainer, member) pair — the trainer is the current user when the other side is a member; simplest correct rule: query `trainer_assignments` with `member_id = otherId`, `status = active`, order assigned_at desc, limit 1; if a row exists, filter loaded messages to `created_at >= assigned_at`. If the other participant is not an assigned member (edge), show all messages.

- [ ] **Step 4: verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze lib/features/member/chat/pages/chat_page.dart lib/features/trainer/chat/pages/chat_room_page.dart
```

Manual: M002 chat with T002 is empty (Aug/Sep rows predate Oct 4); send a message either side — visible both sides; admin reassigns M002 again — chat empties again.

- [ ] **Step 5: commit**

```bash
git add mobile/fitness_app/lib/features/member/chat/pages/chat_page.dart mobile/fitness_app/lib/features/trainer/chat/pages/chat_room_page.dart
git commit -m "fix(chat): messages scoped to active assignment boundary"
```

## Phase D — instant trainer shell + dashboard

- [ ] **Step 1: TrainerShell to StatefulShellRoute.indexedStack**

In `mobile/fitness_app/lib/app/router.dart`: convert the trainer branch from `ShellRoute(builder: (_, __, child) => TrainerShell(child: child), routes: [...])` to `StatefulShellRoute.indexedStack(builder: (context, state, shell) => TrainerShell(navigationShell: shell), branches: [...])` with five branches (dashboard / members / checkin / chat / profile) mirroring the member shell structure already in this file. Change `TrainerShell` to take `StatefulNavigationShell navigationShell` (like MemberShell), replace `_trainerIndex()`/`didChangeDependencies`/`didUpdateWidget` with `navigationShell.currentIndex`, and `_onTap` with `navigationShell.goBranch(index, initialLocation: index == navigationShell.currentIndex)`. Keep TrainerNavBar, all route paths, and the iOS push transitions unchanged. NOTE: nested routes (member detail, chat room, feedback, record, create-plan) must stay reachable — put them as sub-routes of their branch's root (e.g. member detail under /trainer/members, room under /trainer/chat) so the branch state persists.

- [ ] **Step 2: dashboard parallel waves, keep-alive**

In `mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart`: keep `trainerDashboardProvider` (drop nothing from its return shape) but restructure: after memberIds known, fire attendance + memberships + rooms queries in ONE `Future.wait` (they are independent); predictions stay last (depends on data, as today). Replace `.or(id.eq...)` chains with `.inFilter` where a list is used. Provider stays non-autoDispose (cached-first). Add router-listener refresh on return to `/trainer/dashboard` following the member home_page.dart pattern.

- [ ] **Step 3: verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze lib/app/router.dart lib/features/trainer/dashboard/pages/dashboard_page.dart
```

Manual: trainer login, visit all 5 tabs once, then switch — cached render instantly with background refetch; deep links (member detail, chat room) still open with back working.

- [ ] **Step 4: commit**

```bash
git add mobile/fitness_app/lib/app/router.dart mobile/fitness_app/lib/features/trainer/dashboard/pages/dashboard_page.dart
git commit -m "perf(trainer): indexed-stack shell + parallel dashboard queries"
```

## Phase E — members batched queries + search

- [ ] **Step 1: batch assignedMembersWithStatsProvider**

In `mobile/fitness_app/lib/features/trainer/progress/pages/progress_list_page.dart`: change provider from `FutureProvider.autoDispose` to plain `FutureProvider` (keep-alive). Replace the per-member loop with: profiles via `.inFilter('id', memberIds)`; latest measurement per member via ONE `.inFilter('member_id', memberIds).order('measured_at', desc)` query then take first row per member client-side; active goals via ONE `.inFilter('member_id', memberIds).eq('status','active')` then first per member. Fire all three in one `Future.wait`. Add `code` to the profiles select. Remove the `initState` self-invalidate; add router-listener refresh on return to `/trainer/members` (home_page.dart pattern).

- [ ] **Step 2: search box (name + code)**

In `_ProgressListPageState`: add `final _searchController = TextEditingController(); String _query = '';` (dispose controller). Insert a search field widget between `_buildTrainerNavBar('Members')` and the `Expanded` list: a `TextField` with `prefixIcon: Icon(Icons.search)`, `suffixIcon` clear button (visible when `_query.isNotEmpty`, clears controller + setState), `hintText: 'Search members'`, filled dark style matching ClayTokens inputs used elsewhere. Filter: `members.where((m) => name.toLowerCase().contains(q) || (code).toLowerCase().contains(q))`. Empty-filter state: `No members match "<query>"` text in place of the list. Full-list empty state stays as-is.

- [ ] **Step 3: verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze lib/features/trainer/progress/pages/progress_list_page.dart
```

Manual: open Members — loads once; type 'Ryan' and 'M002' — filters; clear restores; switch tabs and back — instant.

- [ ] **Step 4: commit**

```bash
git add mobile/fitness_app/lib/features/trainer/progress/pages/progress_list_page.dart
git commit -m "perf+feat(trainer): batched members query + search box"
```

## Phase F — conversations from assignments + on-demand rooms

- [ ] **Step 1: trainerConversationsProvider**

In `mobile/fitness_app/lib/features/trainer/chat/pages/chat_list_page.dart`, REPLACE `chatRoomsWithProfilesProvider` with:

```dart
/// One row per ACTIVELY assigned member, room attached when it exists.
/// Members with no room yet (never messaged) still appear; tapping their
/// row creates the room on demand. Rooms of non-assigned members are hidden.
final trainerConversationsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final results = await Future.wait([
    client
        .from('trainer_assignments')
        .select('member_id, profiles!trainer_assignments_member_id_fkey(id, full_name, avatar_url, code)')
        .eq('trainer_id', userId)
        .eq('status', 'active'),
    client
        .from('chat_rooms')
        .select('id, participant_one, participant_two')
        .or('participant_one.eq.$userId,participant_two.eq.$userId'),
  ]);
  final assignments = (results[0] as List).cast<Map<String, dynamic>>();
  final rooms = (results[1] as List).cast<Map<String, dynamic>>();

  String? roomIdFor(String memberId) {
    for (final r in rooms) {
      final p1 = r['participant_one'] as String?;
      final p2 = r['participant_two'] as String?;
      if ((p1 == userId && p2 == memberId) || (p1 == memberId && p2 == userId)) {
        return r['id'] as String;
      }
    }
    return null;
  }

  final rows = <Map<String, dynamic>>[];
  for (final a in assignments) {
    final p = a['profiles'] as Map<String, dynamic>?;
    if (p == null) continue;
    final mid = (p['id'] ?? a['member_id']) as String;
    rows.add({
      'memberId': mid,
      'full_name': p['full_name'] as String? ?? 'Unknown',
      'avatar_url': p['avatar_url'] as String?,
      'roomId': roomIdFor(mid),
    });
  }
  rows.sort((x, y) => (x['full_name'] as String).compareTo(y['full_name'] as String));
  return rows;
});
```

Keep every existing import in the file; no new imports needed.

- [ ] **Step 2: list UI with on-demand room creation**

In `_ChatListPageState`: watch `trainerConversationsProvider` instead of the old provider. In the item tap handler: if `r['roomId'] != null`, `context.push('/trainer/chat/${roomId}')`; else insert the room then push it:

```dart
onTap: () async {
  final existing = r['roomId'] as String?;
  if (existing != null) {
    context.push('/trainer/chat/$existing');
    return;
  }
  final client = SupabaseClientService().client;
  final me = client.auth.currentUser!.id;
  final mid = r['memberId'] as String;
  final inserted = await client
      .from('chat_rooms')
      .insert({'participant_one': me, 'participant_two': mid})
      .select('id')
      .single();
  ref.invalidate(trainerConversationsProvider);
  if (context.mounted) {
    context.push('/trainer/chat/${inserted['id']}');
  }
},
```

Keep the existing card visuals; the 'Tap to open conversation' subtitle stays for both states. Empty state text stays ('No conversations yet' — now means no assigned members).

- [ ] **Step 3: verify**

```bash
cd c:/capstsh/mobile/fitness_app && flutter analyze lib/features/trainer/chat/pages/chat_list_page.dart
```

Manual as T002: Conversations shows 12 rows; roomless row tap creates + opens room; revisit shows it directly; unassigned member's room (if any) hidden.

- [ ] **Step 4: commit**

```bash
git add mobile/fitness_app/lib/features/trainer/chat/pages/chat_list_page.dart
git commit -m "fix(trainer): conversations list all assigned members, rooms on demand"
```

## Review focus

1. Indexed-stack conversion must keep nested routes (member detail, chat room, feedback, record, create-plan) reachable with working back navigation — Phase D step 3 manual check covers it.
2. Duplicate active assignments predating Phase A: member queries order by assigned_at desc so the newest wins even before the admin fix heals data.
3. The batched latest-measurement query relies on client-side first-row-per-member after a global desc order — verify a member with 2+ measurements shows the newest.
4. Chat date filter compares ISO strings parsed to DateTime — messages exactly at the assignment second are kept (>=, not >).
5. `members_list_page.dart` (unused legacy page with its own assignedMembersProvider) is intentionally untouched — the Members tab renders progress_list_page.dart.

## Self-review

- Spec coverage: A(admin close-old)→Phase A; B(feedback)→Phase B; C(chat reset)→Phase C; D(shell+dashboard+chat perf)→Phases D+F; E(members search)→Phase E; F(conversations)→Phase F. All covered.
- Placeholders: none — every step names the file, the change, and the verification.
- Type consistency: provider shapes preserved (dashboard return map unchanged; conversation rows use roomId/memberId/full_name/avatar_url keys consistently between Steps 1-2 of Phase F).


