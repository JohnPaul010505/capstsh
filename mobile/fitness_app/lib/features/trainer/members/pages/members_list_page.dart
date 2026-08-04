import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/models/profile.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';

final assignedMembersProvider = FutureProvider<List<Profile>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;
  final response = await client
      .from('trainer_assignments')
      .select('profiles!trainer_assignments_member_id_fkey(*)')
      .eq('trainer_id', userId)
      .eq('status', 'active');
  return (response as List)
      .map((e) => Profile.fromJson(e['profiles'] as Map<String, dynamic>))
      .toList();
});

class MembersListPage extends ConsumerWidget {
  const MembersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(assignedMembersProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text('My Members',
                style: ClayTokens.headlineSmall.copyWith(color: ClayTokens.clayDarkTextPrimary)),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: membersAsync.when(
                data: (members) {
                  if (members.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.group_outlined, color: ClayTokens.clayDarkTextTertiary, size: 48),
                          const SizedBox(height: 12),
                          Text('No assigned members yet', style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => Container(
                      height: 0.5,
                      color: ClayTokens.clayDarkDivider,
                      margin: const EdgeInsets.only(left: 60),
                    ),
                    itemBuilder: (_, i) {
                      final member = members[i];
                      return GestureDetector(
                        onTap: () => context.push('/trainer/members/${member.id}'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ClayTokens.clayDarkSurface,
                                ),
                                alignment: Alignment.center,
                                child: Text(member.fullName[0], style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(member.fullName, style: ClayTokens.bodyLarge.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                                    Text(member.email, style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: ClayTokens.clayDarkTextTertiary, size: 18),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayError))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
