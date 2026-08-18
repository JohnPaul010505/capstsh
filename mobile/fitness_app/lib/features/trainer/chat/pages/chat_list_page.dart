import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

final chatRoomsWithProfilesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final rooms = await client
      .from('chat_rooms')
      .select()
      .or('participant_one.eq.$userId,participant_two.eq.$userId')
      .order('created_at', ascending: false);

  final roomList = (rooms as List).cast<Map<String, dynamic>>();
  final result = <Map<String, dynamic>>[];

  for (final room in roomList) {
    final otherId = (room['participant_one'] as String?) == userId
        ? room['participant_two'] as String?
        : room['participant_one'] as String?;
    if (otherId == null) continue;

    try {
      final profile = await client
          .from('profiles')
          .select('id, full_name, avatar_url')
          .eq('id', otherId)
          .single();
      result.add({
        'roomId': room['id'] as String,
        'memberId': otherId,
        'full_name': profile['full_name'] as String? ?? 'Unknown',
        'avatar_url': profile['avatar_url'] as String?,
      });
    } catch (_) {}
  }

  return result;
});

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(chatRoomsWithProfilesProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final roomsAsync = ref.watch(chatRoomsWithProfilesProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Conversations'),
              Expanded(
                child: roomsAsync.when(
                  data: (rooms) {
                    if (rooms.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.bubble_left, color: ClayTokens.clayDarkTextTertiary, size: 48),
                            const SizedBox(height: 12),
                            Text('No conversations yet', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                          ],
                        ),
                      );
                    }
                     return ListView.builder(
                       padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                       itemCount: rooms.length,
                       itemBuilder: (_, i) {
                         final r = rooms[i];
                         final name = r['full_name'] as String? ?? 'Unknown';
                         final initials = name.split(' ').map((n) => n[0]).take(2).join();
                         final avatarUrl = r['avatar_url'] as String?;
                         return Semantics(
                           label: 'Chat with $name',
                           child: GestureDetector(
                             onTap: () => context.push('/trainer/chat/${r['roomId']}'),
                             child: Container(
                               padding: const EdgeInsets.all(12),
                               margin: const EdgeInsets.only(bottom: 8),
                               decoration: BoxDecoration(
                                 color: ClayTokens.clayDarkSurface,
                                 borderRadius: BorderRadius.circular(16),
                                 border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                               ),
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
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(name, style: ClayTokens.titleLarge.copyWith(
                                           fontSize: 15, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.24)),
                                         const SizedBox(height: 2),
                                         Text('Tap to open conversation',
                                           style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
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
                  error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary))),
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
