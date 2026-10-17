import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../../app/theme_mode_toggle.dart';
import '../../bmi/providers/bmi_history_provider.dart';
import '../../../shared/providers/plan_providers.dart';
import '../../../shared/widgets/glass_sign_out_dialog.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppGlowBackground(
        child: SafeArea(
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
            error: (e, _) => Center(
              child: Text(
                'Error: $e',
                style: const TextStyle(color: Color(0xFF636366)),
              ),
            ),
          ),
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
    final avatarUrl = profile?.avatarUrl;
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
              child: Icon(
                CupertinoIcons.chevron_back,
                color: glassInk(),
                size: 24,
              ),
            ),
            Text(
              'Settings',
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
        StaggeredFadeIn(
          index: 0,
          child: MemberGlassCard(
            padding: const EdgeInsets.all(16),
            borderRadius: BorderRadius.circular(16),
            // Dark mode keeps its exact blurred lilac panel.
            darkBuilder: (cardChild) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimaryLight.withAlpha(25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ClayColors.isLightMode
                          ? ClayTokens.clayPrimary.withAlpha(45)
                          : Colors.white.withAlpha(18),
                    ),
                  ),
                  child: cardChild,
                ),
              ),
            ),
            child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: avatarUrl == null
                                ? null
                                : Colors.transparent,
                            gradient: avatarUrl == null
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFFBF5AF2),
                                      Color(0xFFD6A5FF),
                                    ],
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(40),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: avatarUrl == null
                              ? Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : (avatarUrl!.startsWith('assets/')
                                    ? Image.asset(
                                        avatarUrl,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                      )
                                    : ClipOval(
                                        child: Image.network(
                                          avatarUrl,
                                          width: 52,
                                          height: 52,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Text(
                                            initials,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      )),
                        ),
                        if (gender == 'male' && avatarUrl == null)
                          Positioned(
                            bottom: -3,
                            right: -3,
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1C1C1E),
                                border: Border.all(
                                  color: ClayTokens.clayPrimary,
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                CupertinoIcons.person_fill,
                                color: ClayTokens.clayPrimary,
                                size: 12,
                              ),
                            ),
                          ),
                      ],
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
                          if (email.isNotEmpty)
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 12,
                                color: ClayTokens.clayDarkTextSecondary,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          const SizedBox(height: 2),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 36),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            onPressed: () => _showAvatarPicker(context, ref),
                            child: Text(
                              'Change Profile',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                // Lilac reads on the dark panel but disappears
                                // on the light glass body.
                                color: ClayColors.isLightMode
                                    ? ClayTokens.clayPrimary
                                    : const Color(0xFFD8B4FE),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Features',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: ClayTokens.clayDarkTextTertiary,
            letterSpacing: 0,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 8),
        // Appearance sits at the top of the Features list, right above BMI.
        // Light mode keeps the surrounding GlassPanel; dark mode has NO panel —
        // the toggle paints its own glass body, so the row is one glass surface
        // instead of a flat dark card sitting inside a glass frame.
        ClayColors.isLightMode
            ? GlassPanel(
                padding: const EdgeInsets.all(14),
                borderRadius: BorderRadius.circular(16),
                child: const ThemeModeToggle(),
              )
            : const ThemeModeToggle(),
        const SizedBox(height: 10),
        _SettingItem(
          index: 1,
          icon: CupertinoIcons.gear,
          iconColor: const Color(0xFF0A84FF),
          label: 'BMI',
          subtitle: bmiInfo == null
              ? null
              : '${bmiInfo.bmi.toStringAsFixed(1)} \u00b7 ${bmiInfo.label}',
          onTap: () => context.push('/member/bmi'),
        ),
        const SizedBox(height: 10),
        _SettingItem(
          index: 2,
          icon: CupertinoIcons.bubble_left,
          iconColor: const Color(0xFF30D158),
          label: 'Feedback',
          onTap: () => context.push('/member/feedback'),
        ),
        const SizedBox(height: 10),
        _SettingItem(
          index: 3,
          icon: CupertinoIcons.flag,
          iconColor: const Color(0xFFBF5AF2),
          label: 'Goals',
          onTap: () => context.push('/member/goals'),
        ),
        const SizedBox(height: 10),
        _SettingItem(
          index: 4,
          icon: CupertinoIcons.creditcard,
          iconColor: const Color(0xFF0A84FF),
          label: 'Membership',
          onTap: () => context.push('/member/membership'),
        ),
        const SizedBox(height: 10),
        _SettingItem(
          index: 5,
          icon: CupertinoIcons.doc_text,
          iconColor: const Color(0xFFBF5AF2),
          label: 'Trainer Plan',
          onTap: () => _showTrainerPlanDialog(context, ref),
        ),
        const SizedBox(height: 24),
        Divider(color: glassLine(const Color(0xFF38383A))),
        const SizedBox(height: 8),
        Consumer(
          builder: (_, ref, __) => PressableCard(
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
            border: const Border.fromBorderSide(
              BorderSide(color: Color(0x18FFFFFF)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Sign Out',
                textAlign: TextAlign.center,
                style: TextStyle(
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

  void _showAvatarPicker(BuildContext context, WidgetRef ref) {
    final profile = ref.read(authProvider).valueOrNull;
    final gender = profile?.gender;
    final avatarOptions = gender == 'male'
        ? ['L1', 'L2', 'L3']
        : gender == 'female'
        ? ['W1', 'W2', 'W3']
        : ['L1', 'L2', 'L3', 'W1', 'W2', 'W3'];
    String? selectedAvatar = profile?.avatarUrl;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ClayColors.isLightMode
                ? const Color(0xFFF8F4FF)
                : const Color(0xFF14142A),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Choose Profile',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: glassInk(),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                children: avatarOptions.map((asset) {
                  final isSelected = selectedAvatar == asset;
                  return GestureDetector(
                    onTap: () => setState(() => selectedAvatar = asset),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF7C3AED)
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 36,
                        backgroundImage: AssetImage(
                          'assets/profiles/$asset.gif',
                        ),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: ClayTokens.clayDarkTextSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: glassLine(const Color(0xFF38383A)),
                          ),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        try {
                          await ref
                              .read(authProvider.notifier)
                              .updateProfile(
                                fullName: profile?.fullName ?? '',
                                email: profile?.email ?? '',
                                gender: gender,
                                avatarAsset: selectedAvatar != null
                                    ? 'assets/profiles/$selectedAvatar.gif'
                                    : null,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated'),
                                backgroundColor: Color(0xFF7C3AED),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to update profile: $e'),
                                backgroundColor: const Color(0xFFFF453A),
                              ),
                            );
                          }
                        }
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  void _showTrainerPlanDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Consumer(
        builder: (_, ref, __) {
          final planAsync = ref.watch(activePlanProvider);
          return planAsync.when(
            data: (plan) {
              if (plan == null) return const _NoPlanDialog();
              final status = plan['status'] as String? ?? 'active';
              // The DB never flips `status` when the window simply runs out
              // (getPlanByMember filters on status only), so also treat a plan
              // whose end date has passed as ended - mirroring getActivePlan's
              // `.gte('end_date', today)` window check.
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              final endDate =
                  DateTime.tryParse(plan['end_date']?.toString() ?? '');
              final expired = endDate != null && endDate.isBefore(today);
              if (status != 'active' || expired) {
                return const _NoPlanDialog(
                  message:
                      'The plan is ended. Chat your trainer to add another plan.',
                );
              }
              return _ActivePlanDialog(plan: plan);
            },
            loading: () => const _LoadingDialog(),
            error: (_, __) => _NoPlanDialog(
              message: 'Unable to load plan. Ask your trainer.',
            ),
          );
        },
      ),
    );
  }
}

class _NoPlanDialog extends StatelessWidget {
  final String message;

  const _NoPlanDialog({this.message = 'Ask your trainer to make a plan.'});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 48,
              color: ClayTokens.clayDarkTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ClayTokens.clayDarkTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: ClayTokens.clayPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivePlanDialog extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _ActivePlanDialog({required this.plan});

  @override
  Widget build(BuildContext context) {
    final startDate = plan['start_date'] as String? ?? '';
    final endDate = plan['end_date'] as String? ?? '';
    // `member_goal_plans` has no total_days column - derive the window from
    // the dates (inclusive: assignPlan writes start=now, end=start+6 -> 7 days).
    final start = DateTime.tryParse(startDate);
    final end = DateTime.tryParse(endDate);
    final totalDays = (start != null && end != null)
        ? (end.difference(start).inDays + 1).clamp(1, 3650).toInt()
        : (plan['total_days'] as int? ?? 7);
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc_text,
              size: 48,
              color: ClayTokens.clayPrimaryLight,
            ),
            const SizedBox(height: 16),
            Text(
              'Active Trainer Plan',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ClayTokens.clayDarkTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start: $startDate\nEnd: $endDate\nDuration: $totalDays days',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ClayTokens.clayDarkTextSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: ClayTokens.clayPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingDialog extends StatelessWidget {
  const _LoadingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: GlassPanel(
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: ClayTokens.clayPrimary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading plan...',
              style: TextStyle(
                color: ClayTokens.clayDarkTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
  final String? subtitle;
  final VoidCallback onTap;

  const _SettingItem({
    required this.index,
    required this.icon,
    required this.iconColor,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StaggeredFadeIn(
      index: index,
      child: Semantics(
        label: label,
        child: PressableCard(
          glass: true,
          onTap: onTap,
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
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      color: ClayTokens.clayDarkTextSecondary,
                      fontSize: 13,
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


