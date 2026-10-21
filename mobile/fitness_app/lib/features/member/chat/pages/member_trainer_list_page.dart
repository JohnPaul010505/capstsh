import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';

import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';

/// Active trainers for the signed-in member. This provider only reads data;
/// showing the list never creates chat rooms.
final memberTrainerConversationsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;
      final assignments = await client
          .from('trainer_assignments')
          .select(
            'trainer_id, assigned_at, profiles!trainer_assignments_trainer_id_fkey(id, full_name, avatar_url)',
          )
          .eq('member_id', userId)
          .eq('status', 'active')
          .order('assigned_at', ascending: false);

      return (assignments as List).cast<Map<String, dynamic>>().map((
        assignment,
      ) {
        final profile = assignment['profiles'] as Map<String, dynamic>?;
        return {
          'trainerId': (profile?['id'] ?? assignment['trainer_id']) as String,
          'full_name': profile?['full_name'] as String? ?? 'Trainer',
          'avatar_url': profile?['avatar_url'] as String?,
        };
      }).toList();
    });

class MemberTrainerListPage extends ConsumerStatefulWidget {
  const MemberTrainerListPage({super.key});

  @override
  ConsumerState<MemberTrainerListPage> createState() =>
      _MemberTrainerListPageState();
}

class _MemberTrainerListPageState extends ConsumerState<MemberTrainerListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(memberTrainerConversationsProvider);
    return Scaffold(
      backgroundColor: ClayColors.isLightMode
          ? ClayTokens.claySurfaceLight
          : ClayTokens.clayDarkSurface,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
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
                    onChanged: (value) =>
                        setState(() => _query = value.trim().toLowerCase()),
                    style: ClayTokens.bodyMedium.copyWith(
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search trainers',
                      prefixIcon: Icon(
                        CupertinoIcons.search,
                        color: ClayTokens.clayDarkTextTertiary,
                        size: 18,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: ClayTokens.bodyMedium.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: conversations.when(
                  data: _list,
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        SkeletonCard(),
                        SkeletonCard(),
                      ],
                    ),
                  ),
                  error: (_, __) => _state(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Could not load trainers',
                    detail: 'Please try again in a moment.',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
      ),
    ),
    child: Row(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _goBack,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayDarkTextPrimary,
              size: 24,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Conversations',
            textAlign: TextAlign.center,
            style: ClayTokens.titleLarge.copyWith(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: 40),
      ],
    ),
  );

  Widget _list(List<Map<String, dynamic>> trainers) {
    final filtered = trainers.where((trainer) {
      final name = trainer['full_name'] as String? ?? '';
      return name.toLowerCase().contains(_query);
    }).toList();
    if (filtered.isEmpty) {
      return _state(
        icon: CupertinoIcons.chat_bubble_2,
        title: _query.isEmpty
            ? 'No trainers assigned'
            : 'No trainers match "$_query"',
        detail: _query.isEmpty
            ? 'Contact the gym to get paired with a trainer.'
            : 'Try a different search.',
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      itemCount: filtered.length,
      itemBuilder: (_, index) {
        final trainer = filtered[index];
        final name = trainer['full_name'] as String? ?? 'Trainer';
        final initials = name
            .split(' ')
            .where((part) => part.isNotEmpty)
            .map((part) => part[0])
            .take(2)
            .join();
        return Semantics(
          label: 'Chat with $name',
          child: PressableCard(
            onTap: () => context.push('/member/chat/${trainer['trainerId']}'),
            glass: true,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 8),
            borderRadius: BorderRadius.circular(16),
            child: Row(
              children: [
                ClayAvatar(
                  imageUrl: trainer['avatar_url'] as String?,
                  initials: initials,
                  size: ClayAvatarSize.md,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: ClayTokens.titleLarge.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: ClayTokens.clayDarkTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to open conversation',
                        style: ClayTokens.bodySmall.copyWith(
                          fontSize: 13,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  CupertinoIcons.chevron_right,
                  color: ClayTokens.clayDarkTextTertiary,
                  size: 18,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _state({
    required IconData icon,
    required String title,
    required String detail,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: ClayTokens.clayDarkTextTertiary, size: 48),
          const SizedBox(height: 12),
          Text(
            title,
            style: ClayTokens.titleMedium.copyWith(
              color: ClayTokens.clayDarkTextPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            style: ClayTokens.bodySmall.copyWith(
              color: ClayTokens.clayDarkTextTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/member/home');
    }
  }
}
