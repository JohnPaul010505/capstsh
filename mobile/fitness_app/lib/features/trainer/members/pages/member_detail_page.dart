import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/profile.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

final memberDetailProvider = FutureProvider.family<Profile?, String>((ref, id) async {
  final client = SupabaseClientService().client;
  final response = await client.from('profiles').select().eq('id', id).single();
  return Profile.fromJson(response);
});

class MemberDetailPage extends ConsumerWidget {
  final String id;
  const MemberDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memberAsync = ref.watch(memberDetailProvider(id));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: SafeArea(
        child: memberAsync.when(
          data: (member) {
            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(Icons.chevron_left, color: ClayTokens.clayDarkTextPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    ClayAvatar(
                      initials: member!.fullName[0],
                      size: ClayAvatarSize.md,
                    ),
                    const SizedBox(width: 10),
                    Text(member.fullName, style: ClayTokens.titleLarge.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                  ],
                ),
                const SizedBox(height: 16),
                ClayCard(
                  variant: ClayCardVariant.outlined,
                  padding: ClayCardPadding.medium,
                  child: Row(
                    children: [
                      ClayAvatar(
                        initials: member.fullName[0],
                        size: ClayAvatarSize.lg,
                        backgroundColor: ClayTokens.clayPrimary,
                        textColor: ClayTokens.clayDarkTextPrimary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.fullName, style: ClayTokens.titleLarge.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                            Text(member.email, style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ClayCard(
                  variant: ClayCardVariant.outlined,
                  padding: ClayCardPadding.none,
                  child: Column(
                    children: [
                      _DetailTile(icon: Icons.directions_walk, title: 'View Workouts', onTap: () {}),
                      _DetailTile(icon: Icons.trending_up, title: 'View Progress', onTap: () {}),
                      _DetailTile(icon: Icons.flag_outlined, title: 'Goals', onTap: () {}),
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayError))),
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _DetailTile({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: ClayTokens.clayDarkDivider)),
        ),
        child: Row(
          children: [
            Icon(icon, color: ClayTokens.clayDarkTextTertiary, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(title, style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary))),
            Icon(Icons.chevron_right, color: ClayTokens.clayDarkTextTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
