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

/// Active trainers for the signed-in member, with plan status per trainer.
/// Trainers without a plan remain selectable and show an empty state on
/// detail. Showing the list never creates plans or rooms, and never changes
/// display state.
final memberTrainerPlansProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return <Map<String, dynamic>>[];

      final assignments = await client
          .from('trainer_assignments')
          .select(
            'trainer_id, assigned_at, profiles!trainer_assignments_trainer_id_fkey(id, full_name, avatar_url)',
          )
          .eq('member_id', userId)
          .eq('status', 'active')
          .order('assigned_at', ascending: false);

      final rows = (assignments as List).cast<Map<String, dynamic>>();

      final now = DateTime.now();
      final today = DateTime(
        now.year,
        now.month,
        now.day,
      ).toIso8601String().split('T').first;

      // Assigned plans are visible before their start date. Workout/Food
      // still use the current-date window for daily activity.
      final plansResponse = await client
          .from('member_goal_plans')
          .select('id, trainer_id, is_displayed, start_date, end_date')
          .eq('member_id', userId)
          .eq('status', 'active')
          .gte('end_date', today)
          .order('start_date', ascending: false);

      final plans = (plansResponse as List).cast<Map<String, dynamic>>();
      final planByTrainer = <String, Map<String, dynamic>>{};
      for (final plan in plans) {
        final trainerId = plan['trainer_id'] as String?;
        if (trainerId == null) continue;
        // Newest-first ordering means the first row seen per trainer wins.
        planByTrainer.putIfAbsent(trainerId, () => plan);
      }

      return rows.map((assignment) {
        final profile = assignment['profiles'] as Map<String, dynamic>?;
        final trainerId =
            (profile?['id'] ?? assignment['trainer_id']) as String;
        final plan = planByTrainer[trainerId];
        return {
          'trainerId': trainerId,
          'full_name': profile?['full_name'] as String? ?? 'Trainer',
          'avatar_url': profile?['avatar_url'] as String?,
          'hasPlan': plan != null,
          'isDisplayed': plan?['is_displayed'] as bool? ?? false,
          'planId': plan?['id'] as String?,
          'scheduledStart':
              plan != null &&
                  (plan['start_date'] as String).compareTo(today) > 0
              ? plan['start_date'] as String
              : null,
        };
      }).toList();
    });

class MemberTrainerPlanListPage extends ConsumerStatefulWidget {
  const MemberTrainerPlanListPage({super.key});

  @override
  ConsumerState<MemberTrainerPlanListPage> createState() =>
      _MemberTrainerPlanListPageState();
}

class _MemberTrainerPlanListPageState
    extends ConsumerState<MemberTrainerPlanListPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trainers = ref.watch(memberTrainerPlansProvider);
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
              _searchBar(),
              Expanded(
                child: trainers.when(
                  data: _list,
                  loading: _loading,
                  error: (_, __) => _state(
                    icon: CupertinoIcons.exclamationmark_triangle,
                    title: 'Could not load your plans',
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
            'Trainer Plan',
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

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
    child: GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
  );

  Widget _loading() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Column(
      children: const [
        SizedBox(height: 8),
        SkeletonCard(),
        SkeletonCard(),
        SkeletonCard(),
      ],
    ),
  );

  Widget _list(List<Map<String, dynamic>> trainers) {
    final filtered = trainers
        .where(
          (trainer) => (trainer['full_name'] as String? ?? '')
              .toLowerCase()
              .contains(_query),
        )
        .toList();
    if (filtered.isEmpty) {
      return _state(
        icon: _query.isEmpty
            ? CupertinoIcons.calendar_badge_minus
            : CupertinoIcons.search,
        title: _query.isEmpty ? 'No trainers assigned' : 'No matching trainers',
        detail: _query.isEmpty
            ? 'Contact the gym to get paired with a trainer.'
            : 'Try a different search.',
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(memberTrainerPlansProvider);
        await ref.read(memberTrainerPlansProvider.future);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        itemCount: filtered.length,
        itemBuilder: (_, index) => _trainerCard(filtered[index]),
      ),
    );
  }

  Widget _trainerCard(Map<String, dynamic> trainer) {
    final name = trainer['full_name'] as String? ?? 'Trainer';
    final trainerId = trainer['trainerId'] as String;
    final hasPlan = trainer['hasPlan'] as bool? ?? false;
    final isDisplayed = trainer['isDisplayed'] as bool? ?? false;
    final scheduledStart = trainer['scheduledStart'] as String?;
    final initials = name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join();

    return Semantics(
      label: 'View plan for $name${hasPlan ? '' : ' — no plan yet'}',
      child: PressableCard(
        glass: true,
        onTap: () => context.push(
          '/member/trainer-plan/$trainerId'
          '?name=${Uri.encodeQueryComponent(name)}',
        ),
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
                  Row(
                    children: [
                      Icon(
                        isDisplayed
                            ? CupertinoIcons.eye_fill
                            : CupertinoIcons.doc_text,
                        color: isDisplayed
                            ? ClayTokens.clayPrimary
                            : ClayTokens.clayDarkTextTertiary,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          scheduledStart != null
                              ? 'Starts $scheduledStart'
                              : hasPlan
                              ? (isDisplayed
                                    ? 'Displayed on Workout & Food'
                                    : 'Plan not displayed')
                              : 'No plan yet',
                          style: ClayTokens.bodySmall.copyWith(
                            fontSize: 12,
                            color: isDisplayed
                                ? ClayTokens.clayPrimary
                                : ClayTokens.clayDarkTextTertiary,
                          ),
                        ),
                      ),
                    ],
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
