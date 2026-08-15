import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';

import 'package:shared/services/supabase_client.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';

final trainerProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final client = SupabaseClientService().client;
  final response = await client.from('profiles').select('id, full_name, email, created_at, specialty, available_days').eq('id', id).single();
  return response;
});

Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: ClayTokens.clayDarkTextTertiary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextSecondary, fontSize: 10)),
                const SizedBox(height: 2),
                Text(value, style: ClayTokens.labelMedium.copyWith(color: ClayTokens.clayDarkTextPrimary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
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

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = SupabaseClientService().client.auth.currentUser!.id;
    final profileAsync = ref.watch(trainerProfileProvider(currentUserId));
    final profile = profileAsync.value;
    final email = profile?['email'] as String? ?? '';
    final createdAt = profile?['created_at'] as String? ?? '';
    final since = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
    final specialty = profile?['specialty'] as String?;
    final availableDays = profile?['available_days'] as String?;

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Profile'),
              Expanded(
                child: profileAsync.when(
                  data: (profile) {
                    final name = profile['full_name'] as String? ?? 'Trainer';
                    final initials = name.split(' ').map((n) => n[0]).take(2).join();
                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              Stack(
                                children: [
                                  Container(
                                    width: 72, height: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: ClayTokens.clayDarkSurfaceElevated,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(initials, style: ClayTokens.headlineMedium.copyWith(
                                      fontSize: 22, color: ClayTokens.clayDarkTextPrimary, fontWeight: FontWeight.w600)),
                                    ),
                                  Positioned(
                                    right: 0, bottom: 0,
                                    child: Container(
                                      width: 22, height: 22,
                                      decoration: BoxDecoration(
                                        color: ClayTokens.clayPrimary,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(CupertinoIcons.person, color: ClayTokens.clayDarkTextPrimary, size: 10),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(name, style: ClayTokens.headlineMedium.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: 0.38)),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                decoration: BoxDecoration(
                                  color: ClayTokens.clayPrimary,
                                  borderRadius: const BorderRadius.all(Radius.circular(20)),
                                ),
                                child: Text('TRAINER',
                                  style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextPrimary, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                              ),
                              if (specialty != null && specialty.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: ClayTokens.clayDarkSurface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.bolt, color: ClayTokens.clayDarkTextTertiary, size: 12),
                                      const SizedBox(width: 5),
                                      Text(specialty, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: ClayTokens.clayDarkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                          ),
                          child: Column(
                            children: [
                              _infoRow(icon: CupertinoIcons.mail, label: 'Email', value: email),
                              _infoRow(icon: CupertinoIcons.shield, label: 'Role', value: 'Trainer'),
                              if (since.isNotEmpty)
                                _infoRow(icon: CupertinoIcons.calendar, label: 'Since', value: since),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          decoration: BoxDecoration(
                            color: ClayTokens.clayDarkSurface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                          ),
                          child: Column(
                            children: [
                              if (specialty != null && specialty.isNotEmpty)
                                _infoRow(icon: CupertinoIcons.star, label: 'Specialty', value: specialty),
                              if (availableDays != null && availableDays.isNotEmpty)
                                _infoRow(icon: CupertinoIcons.calendar, label: 'Available', value: availableDays),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Consumer(
                          builder: (_, ref, __) => PressableCard(
                            onTap: () => ref.read(authProvider.notifier).signOut(),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            color: ClayTokens.clayError.withAlpha(15),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: ClayTokens.clayError.withAlpha(50)),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(CupertinoIcons.square_arrow_right, color: ClayTokens.clayError, size: 16),
                                const SizedBox(width: 8),
                                Text('Sign Out',
                                  style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayError, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: -0.24)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                  loading: () => const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SkeletonBox(width: 72, height: 72, borderRadius: 36),
                          SizedBox(height: 12),
                          SkeletonBox(width: 140, height: 18),
                          SizedBox(height: 8),
                          SkeletonBox(width: 80, height: 24, borderRadius: 12),
                          SizedBox(height: 24),
                          SkeletonBox(height: 50),
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