import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../bmi/providers/bmi_history_provider.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: SafeArea(
        child: authState.when(
          data: (profile) => _SettingsContent(profile: profile),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: [
                SizedBox(height: 20),
                Row(
                  children: [
                    SkeletonBox(width: 24, height: 24, borderRadius: 12),
                    SizedBox(width: 12),
                    SkeletonBox(width: 100, height: 20),
                  ],
                ),
                SizedBox(height: 24),
                SkeletonBox(height: 72),
                SizedBox(height: 24),
                SkeletonBox(width: 80, height: 14),
                SizedBox(height: 12),
                SkeletonBox(height: 50),
                SizedBox(height: 8),
                SkeletonBox(height: 50),
                SizedBox(height: 8),
                SkeletonBox(height: 50),
                SizedBox(height: 8),
                SkeletonBox(height: 50),
                SizedBox(height: 8),
                SkeletonBox(height: 50),
              ],
            ),
          ),
          error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Color(0xFF636366)))),
        ),
      ),
    );
  }
}

class _SettingsContent extends ConsumerWidget {
  final dynamic profile;

  const _SettingsContent({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.fullName ?? 'User';
    final email = profile?.email ?? '';
    final gender = profile?.gender as String?;
    final initials = name.split(' ').map((n) => n[0]).take(2).join();
    final bmiInfo = ref.watch(latestBmiProvider).valueOrNull;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      children: [
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: const Icon(CupertinoIcons.chevron_back, color: Color(0xFFFFFFFF), size: 24),
            ),
            const Text('Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
            const SizedBox(width: 24),
          ],
        ),
        const SizedBox(height: 24),
        StaggeredFadeIn(
          index: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38383A).withAlpha(100)),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 52, height: 52,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFFBF5AF2), Color(0xFFD6A5FF)],
                        ),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withAlpha(40), blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(initials, style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700,
                      )),
                    ),
                    if (gender == 'male')
                      Positioned(
                        bottom: -3,
                        right: -3,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF1C1C1E),
                            border: Border.all(color: ClayTokens.clayPrimary, width: 1.5),
                          ),
                          alignment: Alignment.center,
                          child: Icon(CupertinoIcons.person_fill, color: ClayTokens.clayPrimary, size: 12),
                        ),
                      ),
                  ],
                ),
                    const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
                      if (email.isNotEmpty)
                        Text(email, style: const TextStyle(
                          fontSize: 12, color: Color(0xFF636366),
                          decoration: TextDecoration.none,
                        )),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text('Features', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: const Color(0xFF8E8E93), letterSpacing: 0, decoration: TextDecoration.none)),
        const SizedBox(height: 8),
        _SettingItem(index: 1, icon: CupertinoIcons.gear, iconColor: const Color(0xFF0A84FF), label: 'BMI', subtitle: bmiInfo == null ? null : '${bmiInfo.bmi.toStringAsFixed(1)} \u00b7 ${bmiInfo.label}', onTap: () => context.push('/member/bmi')),
        _SettingItem(index: 2, icon: CupertinoIcons.bubble_left, iconColor: const Color(0xFF30D158), label: 'Feedback', onTap: () => context.push('/member/feedback')),
        _SettingItem(index: 3, icon: CupertinoIcons.bell, iconColor: const Color(0xFF64D2FF), label: 'Notifications', onTap: () => context.push('/member/notifications')),
        const SizedBox(height: 24),
        const Divider(color: Color(0xFF38383A)),
        const SizedBox(height: 8),
        Consumer(
          builder: (_, ref, __) => PressableCard(
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: ClayTokens.clayDarkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Sign Out', style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 17, fontWeight: FontWeight.w700, decoration: TextDecoration.none)),
                  content: const Text('Are you sure you want to sign out?', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14, decoration: TextDecoration.none)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('No', style: TextStyle(color: Color(0xFF8E8E93), fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Yes', style: TextStyle(color: Color(0xFFFF453A), fontSize: 14, fontWeight: FontWeight.w600, decoration: TextDecoration.none)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(authProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              }
            },
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Sign Out',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFFF453A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class _SettingItem extends StatelessWidget {
  final int index;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingItem({
    required this.index, required this.icon, required this.iconColor, required this.label,
    this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: index,
      child: Semantics(
        label: label,
        child: PressableCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(BorderSide(color: Color(0xFF38383A))),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: const TextStyle(
                  color: Color(0xFFFFFFFF), fontSize: 14,
                )),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(subtitle!, style: const TextStyle(
                    color: Color(0xFF8E8E93), fontSize: 13,
                  )),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
