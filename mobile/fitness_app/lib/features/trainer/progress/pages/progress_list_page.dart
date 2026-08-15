import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

final assignedMembersWithStatsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final assignments = await client
      .from('trainer_assignments')
      .select('member_id')
      .eq('trainer_id', userId)
      .eq('status', 'active');

  final memberIds = (assignments as List).map((a) => a['member_id'] as String).toList();
  if (memberIds.isEmpty) return [];

  final profiles = await client
      .from('profiles')
      .select('id, full_name, avatar_url, email, gender, phone, date_of_birth')
      .or(memberIds.map((id) => 'id.eq.$id').join(','));

  final profileList = (profiles as List).cast<Map<String, dynamic>>();

  final result = <Map<String, dynamic>>[];
  for (final p in profileList) {
    final mid = p['id'] as String;
    final measurement = await client
        .from('body_measurements')
        .select('weight_kg, height_cm')
        .eq('member_id', mid)
        .order('measured_at', ascending: false)
        .limit(1);

    final goal = await client
        .from('goals')
        .select('title')
        .eq('member_id', mid)
        .eq('status', 'active')
        .limit(1);

    Map<String, dynamic>? meas;
    if ((measurement as List).isNotEmpty) {
      meas = measurement[0] as Map<String, dynamic>?;
    }

    String? goalTitle;
    if ((goal as List).isNotEmpty) {
      goalTitle = goal[0]['title'] as String?;
    }

    result.add({
      'id': mid,
      'full_name': p['full_name'] as String? ?? 'Unknown',
      'avatar_url': p['avatar_url'] as String?,
      'email': p['email'] as String? ?? '',
      'gender': p['gender'] as String? ?? '',
      'phone': p['phone'] as String? ?? '',
      'date_of_birth': p['date_of_birth'] as String? ?? '',
      'weight_kg': meas?['weight_kg'],
      'height_cm': meas?['height_cm'],
      'goal': goalTitle,
    });
  }

  return result;
});

class ProgressListPage extends ConsumerStatefulWidget {
  const ProgressListPage({super.key});

  @override
  ConsumerState<ProgressListPage> createState() => _ProgressListPageState();
}

class _ProgressListPageState extends ConsumerState<ProgressListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(assignedMembersWithStatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(assignedMembersWithStatsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Members'),
              Expanded(
                child: membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(CupertinoIcons.person_2, color: ClayTokens.clayDarkTextTertiary, size: 48),
                            const SizedBox(height: 12),
                            Text('No assigned members yet', style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      itemCount: members.length,
                      itemBuilder: (_, i) {
                        final m = members[i];
                        final name = m['full_name'] as String? ?? 'Unknown';
                        final initials = name.split(' ').map((n) => n[0]).take(2).join();
                        final avatarUrl = m['avatar_url'] as String?;
                        final weight = m['weight_kg'];
                        final height = m['height_cm'];

                        return Semantics(
                          label: 'View $name progress',
                          child: PressableCard(
                            onTap: () => context.push('/trainer/members/${m['id']}'),
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 8),
                            color: ClayTokens.clayDarkSurface,
                            border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
                            borderRadius: BorderRadius.circular(16),
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
                                      if (weight != null || height != null)
                                        Text(
                                          '${weight != null ? '$weight kg' : ''}${weight != null && height != null ? '  ·  ' : ''}${height != null ? '$height cm' : ''}',
                                          style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
                                    ],
                                  ),
                                ),
                              ],
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