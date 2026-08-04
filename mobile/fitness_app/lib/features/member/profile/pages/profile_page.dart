import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_button.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: authState.when(
        data: (profile) => SafeArea(
          child: Column(
            children: [
              _buildNavBar(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  children: [
                    ClayCard(
                      variant: ClayCardVariant.elevated,
                      padding: ClayCardPadding.large,
                      child: Column(
                        children: [
                          ClayAvatar(
                            initials: (profile?.fullName ?? '?')[0].toUpperCase(),
                            size: ClayAvatarSize.xl,
                            backgroundColor: ClayTokens.clayPrimary,
                            textColor: ClayTokens.clayDarkTextPrimary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            profile?.fullName ?? '',
                            textAlign: TextAlign.center,
                            style: ClayTokens.headlineMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: ClayTokens.clayDarkTextPrimary,
                              letterSpacing: 0.38,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            profile?.email ?? '',
                            textAlign: TextAlign.center,
                            style: ClayTokens.bodyLarge.copyWith(
                              fontSize: 15,
                              color: ClayTokens.clayDarkTextSecondary,
                              letterSpacing: -0.24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    ClayFeatureCard(
                      icon: Icons.settings_outlined,
                      iconColor: ClayTokens.clayPrimary,
                      title: 'Settings',
                      subtitle: 'Account and app preferences',
                      onTap: () => context.push('/member/settings'),
                      borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
                    ),
                    const SizedBox(height: 24),
                    ClayButton(
                      label: 'Sign Out',
                      onPressed: () => ref.read(authProvider.notifier).signOut(),
                      style: ClayButtonStyle.destructive,
                      fullWidth: true,
                      size: ClayButtonSize.large,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(
            'Error: $e',
            style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError),
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
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
              'Profile',
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
}
