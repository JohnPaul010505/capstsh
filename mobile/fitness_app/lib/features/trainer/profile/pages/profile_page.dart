import '../../../shared/widgets/profile_details_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:fitness_app/app/theme_mode_toggle.dart';

import 'package:shared/services/supabase_client.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_sign_out_dialog.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/animations.dart';

final trainerProfileProvider =
    StreamProvider.family<Map<String, dynamic>, String>(
      (ref, id) => SupabaseClientService().client
          .from('profiles')
          .stream(primaryKey: ['id'])
          .eq('id', id)
          .map((rows) => rows.single),
    );

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = SupabaseClientService().client.auth.currentUser!.id;
    final profileAsync = ref.watch(trainerProfileProvider(currentUserId));

    return Scaffold(
      backgroundColor: ClayColors.isLightMode
          ? ClayTokens.claySurfaceLight.withAlpha(250)
          : ClayTokens.clayDarkSurface,
      body: AppGlowBackground(
        child: SafeArea(
          child: profileAsync.when(
            data: (profile) {
              final name = profile['full_name'] as String? ?? 'Trainer';
              final email = profile['email'] as String? ?? '';
              final createdAt = profile['created_at'] as String? ?? '';
              final since = createdAt.length >= 10
                  ? createdAt.substring(0, 10)
                  : '';
              final initials = name.split(' ').map((n) => n[0]).take(2).join();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      Text(
                        'Profile',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: ClayTokens.clayDarkTextPrimary,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Same liquid-glass body as the Appearance card in light
                  // mode; dark keeps the original clay fill + hairline.
                  PressableCard(
                    glass: true,
                    padding: const EdgeInsets.all(16),
                    borderRadius: BorderRadius.circular(16),
                    color: ClayTokens.clayPrimaryLight.withAlpha(25),
                    border: Border.all(
                      color: ClayColors.isLightMode
                          ? ClayTokens.clayPrimary.withAlpha(45)
                          : Colors.white.withAlpha(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ClayTokens.clayPrimaryLight.withAlpha(35),
                            border: Border.all(
                              color: ClayTokens.clayPrimary.withAlpha(50),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: ClayTokens.clayPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: ClayTokens.clayDarkTextPrimary,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (email.isNotEmpty)
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: ClayTokens.clayDarkTextSecondary,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text(
                                    'Trainer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ClayTokens.clayPrimary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (since.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '· Since $since',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: ClayTokens.clayDarkTextSecondary,
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Features',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.clayDarkTextSecondary,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Appearance sits at the top of the features list, right
                  // above Create Plan.
                  const ThemeModeToggle(),
                  const SizedBox(height: 8),
                  _SettingItem(
                    index: 1,
                    icon: CupertinoIcons.flag,
                    iconColor: Color(0xFFBF5AF2),
                    label: 'Create Plan',
                    onTap: () => context.go('/trainer/set-plan'),
                  ),
                  const SizedBox(height: 8),
                  _SettingItem(
                    index: 2,
                    icon: CupertinoIcons.doc_text,
                    iconColor: Color(0xFF0A84FF),
                    label: 'Record',
                    onTap: () => context.go('/trainer/record'),
                  ),
                  const SizedBox(height: 8),
                  _SettingItem(
                    index: 3,
                    icon: Icons.rate_review_outlined,
                    iconColor: Color(0xFF30D158),
                    label: 'Feedback',
                    onTap: () => context.push('/trainer/feedback'),
                  ),
                  TrainerProfileTabs(trainerId: currentUserId),
                  const SizedBox(height: 24),
                  PressableCard(
                    glass: true,
                    onTap: () async {
                      final confirm = await showGlassSignOutDialog(context);
                      if (confirm) {
                        ref.read(authProvider.notifier).signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      }
                    },
                    color: ClayTokens.clayPrimaryLight.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: ClayColors.isLightMode
                          ? ClayTokens.clayPrimary.withAlpha(45)
                          : Colors.white.withAlpha(18),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Center(
                      child: Text(
                        'Sign Out',
                        style: TextStyle(
                          color: ClayTokens.clayError,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SkeletonBox(width: 52, height: 52, borderRadius: 26),
                  SizedBox(height: 12),
                  SkeletonBox(width: 140, height: 18),
                  SizedBox(height: 8),
                  SkeletonBox(width: 200, height: 14),
                  SizedBox(height: 24),
                  SkeletonBox(height: 50),
                ],
              ),
            ),
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: TextStyle(color: ClayTokens.clayError),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  const _SettingItem({
    required this.index,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: index,
      child: Semantics(
        label: label,
        child: PressableCard(
          onTap: onTap,
          // Light mode: same glass body as the Appearance card; dark keeps
          // the original clay pill.
          glass: true,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          color: ClayTokens.clayPrimaryLight.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.fromBorderSide(
            BorderSide(
              color: ClayColors.isLightMode
                  ? ClayTokens.clayPrimary.withAlpha(45)
                  : const Color(0x18FFFFFF),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: ClayTokens.clayDarkTextPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: ClayTokens.clayDarkTextSecondary,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
