import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';

/// One row per ACTIVELY assigned member, room attached when it exists.
/// Members with no room yet (never messaged) still appear; tapping their
/// row creates the room on demand. Rooms of non-assigned members are hidden
/// (consistent with the assignment-boundary reset).
final trainerConversationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final results = await Future.wait([
    client
        .from('trainer_assignments')
        .select(
          'member_id, profiles!trainer_assignments_member_id_fkey(id, full_name, avatar_url, code)',
        )
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
      if ((p1 == userId && p2 == memberId) ||
          (p1 == memberId && p2 == userId)) {
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
  rows.sort(
    (x, y) => (x['full_name'] as String).compareTo(y['full_name'] as String),
  );
  return rows;
});

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(trainerConversationsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Conversations'),
              // Search box (name filter) — mirrors the Member Progress list's
              // search field so both trainer tabs feel identical.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) =>
                        setState(() => _query = v.trim().toLowerCase()),
                    style: ClayTokens.bodyLarge.copyWith(
                      color: ClayTokens.clayDarkTextPrimary,
                      fontSize: 14,
                    ),
                    cursorColor: ClayTokens.clayPrimary,
                    decoration: InputDecoration(
                      hintText: 'Search conversations',
                      hintStyle: ClayTokens.bodySmall.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: ClayTokens.clayDarkTextTertiary,
                        size: 18,
                      ),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: ClayTokens.clayDarkTextTertiary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.transparent,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Colors.white.withAlpha(24),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: ClayTokens.clayPrimary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: roomsAsync.when(
                  data: (rooms) {
                    final filtered = _query.isEmpty
                        ? rooms
                        : rooms
                            .where((r) => (r['full_name'] as String? ?? '')
                                .toLowerCase()
                                .contains(_query))
                            .toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _query.isEmpty
                                  ? CupertinoIcons.bubble_left
                                  : Icons.search_off,
                              color: ClayTokens.clayDarkTextTertiary,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _query.isEmpty
                                  ? 'No conversations yet'
                                  : 'No members match "$_query"',
                              style: ClayTokens.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: ClayTokens.clayDarkTextTertiary,
                                letterSpacing: -0.08,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final r = filtered[i];
                        final name = r['full_name'] as String? ?? 'Unknown';
                        final initials = name
                            .split(' ')
                            .map((n) => n[0])
                            .take(2)
                            .join();
                        final avatarUrl = r['avatar_url'] as String?;
                        return Semantics(
                          label: 'Chat with $name',
                          child: GestureDetector(
                            onTap: () async {
                              // Room exists: open it. Otherwise create it on
                              // demand so every assigned member is reachable.
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
                                  .insert({
                                    'participant_one': me,
                                    'participant_two': mid,
                                  })
                                  .select('id')
                                  .single();
                              ref.invalidate(trainerConversationsProvider);
                              if (context.mounted) {
                                context.push('/trainer/chat/${inserted['id']}');
                              }
                            },
                            child: GlassCardLight(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  ClayAvatar(
                                    imageUrl: avatarUrl,
                                    initials: initials,
                                    size: ClayAvatarSize.md,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: ClayTokens.titleLarge.copyWith(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                ClayTokens.clayDarkTextPrimary,
                                            letterSpacing: -0.24,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Tap to open conversation',
                                          style: ClayTokens.bodySmall.copyWith(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color:
                                                ClayTokens.clayDarkTextTertiary,
                                            letterSpacing: -0.08,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        SkeletonCard(),
                        SkeletonCard(),
                        SkeletonCard(),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: ClayTokens.labelMedium.copyWith(
                        fontWeight: FontWeight.w400,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildTrainerNavBar(String title) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        const SizedBox(width: 32),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextPrimary,
              letterSpacing: -0.41,
            ),
          ),
        ),
        const SizedBox(width: 32),
      ],
    ),
  );
}
