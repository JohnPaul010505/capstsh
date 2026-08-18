import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fitness_app/app/design_tokens.dart';

import 'package:shared/services/supabase_client.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/skeleton.dart';

final trainerProfileProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, id) async {
  final client = SupabaseClientService().client;
  final response = await client.from('profiles').select('id, full_name, email, created_at, specialty, available_days').eq('id', id).single();
  return response;
});

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = SupabaseClientService().client.auth.currentUser!.id;
    final profileAsync = ref.watch(trainerProfileProvider(currentUserId));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: profileAsync.when(
            data: (profile) {
              final name = profile['full_name'] as String? ?? 'Trainer';
              final email = profile['email'] as String? ?? '';
              final createdAt = profile['created_at'] as String? ?? '';
              final since = createdAt.length >= 10 ? createdAt.substring(0, 10) : '';
              final initials = name.split(' ').map((n) => n[0]).take(2).join();

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      const Text('Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
                      const SizedBox(width: 24),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: ClayTokens.clayPrimaryLight.withAlpha(25),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withAlpha(18)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: ClayTokens.clayPrimaryLight.withAlpha(35),
                            border: Border.all(color: ClayTokens.clayPrimary.withAlpha(50)),
                          ),
                          alignment: Alignment.center,
                          child: Text(initials, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: ClayTokens.clayPrimary)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF), decoration: TextDecoration.none)),
                              const SizedBox(height: 4),
                              if (email.isNotEmpty)
                                Text(email, style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), decoration: TextDecoration.none)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('Trainer', style: TextStyle(fontSize: 12, color: ClayTokens.clayPrimary, fontWeight: FontWeight.w600)),
                                  if (since.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Text('· Since $since', style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93), decoration: TextDecoration.none)),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Color(0xFF38383A)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: ClayTokens.clayDarkSurface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text('Sign Out', style: TextStyle(color: ClayTokens.clayDarkTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
                          content: Text('Are you sure you want to sign out?', style: TextStyle(color: ClayTokens.clayDarkTextSecondary, fontSize: 14)),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: Text('No', style: TextStyle(color: ClayTokens.clayDarkTextTertiary, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                ref.read(authProvider.notifier).signOut();
                                if (context.mounted) {
                                  context.go('/login');
                                }
                              },
                              child: Text('Yes', style: TextStyle(color: ClayTokens.clayError, fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: ClayTokens.clayPrimaryLight.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withAlpha(18)),
                      ),
                      child: Center(
                        child: Text(
                          'Sign Out',
                          style: TextStyle(color: ClayTokens.clayError, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
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
            error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: ClayTokens.clayError))),
          ),
        ),
      ),
    );
  }
}
