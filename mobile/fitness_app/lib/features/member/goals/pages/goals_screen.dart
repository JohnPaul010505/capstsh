import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/animations.dart'
    show StaggeredFadeIn, Shimmer;
import 'create_goal_card.dart';
import 'goal_card.dart';
import 'empty_goals_state.dart';

const bgDark = Color(0xFF0B0D1A);
const textSecondary = Color(0xFFA0A4B8);

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService().client
      .from('goals')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return CupertinoPageScaffold(
      backgroundColor: bgDark,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Goals'),
              Expanded(
                child: goalsAsync.when(
                  data: (goals) => _GoalsBody(
                    goals: goals,
                    onGoalAdded: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Goal created'),
                          backgroundColor: const Color(0xFF22C55E),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    onToggleStatus: (g) async {
                      final currentStatus = g['status'] as String? ?? 'active';
                      final newStatus =
                          currentStatus == 'active' ? 'completed' : 'active';
                      await SupabaseClientService().client
                          .from('goals')
                          .update({'status': newStatus})
                          .eq('id', g['id']);
                      final userId = SupabaseClientService()
                          .client
                          .auth
                          .currentUser!
                          .id;
                      if (newStatus == 'completed') {
                        // Self-notifications are denied by the notifications insert policy
                        // (user_id <> auth.uid()); a failed notification must never block
                        // the status refresh below.
                        try {
                          await NotificationService().createNotification(
                            userId: userId,
                            title: 'Goal Completed',
                            body:
                                'Congratulations! You completed your ${g['goal_type'] ?? 'fitness'} goal.',
                          );
                        } catch (e) {
                          debugPrint('GOAL NOTIFY failed: $e');
                        }
                      }
                      ref.invalidate(goalsProvider);
                    },
                  ),
                  loading: () => ListView(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    children: [
                      StaggeredFadeIn(
                        index: 0,
                        child: _GoalsSkeletonCard(),
                      ),
                    ],
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error: $e',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: Icon(CupertinoIcons.back, color: Colors.white),
          ),
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
}


/// Goals list body: while any goal's window is still running only the goals
/// show; the Create card shows above the list only when every goal's end
/// date has passed (or none exists yet).
class _GoalsBody extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final VoidCallback onGoalAdded;
  final void Function(Map<String, dynamic> goal) onToggleStatus;

  const _GoalsBody({
    required this.goals,
    required this.onGoalAdded,
    required this.onToggleStatus,
  });

  /// A goal is ongoing while its end date has not passed — regardless of DB
  /// status (active, in_progress, or completed-early) — so the member always
  /// sees just their goal and cannot accidentally add a second one while the
  /// window is still running. A missing/unparseable end date counts as
  /// ongoing (safe side: the Create card stays hidden). The date comparison
  /// matches GoalCard's own isOverdue check so UI and predicate stay in sync.
  bool _ongoing(Map<String, dynamic> g) {
    final end = DateTime.tryParse(g['end_date']?.toString() ?? '');
    return end == null || !end.isBefore(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveGoal = goals.any(_ongoing);
    final activeCount = goals.where(_ongoing).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        _GoalsSectionHeader(
          hasActiveGoal: hasActiveGoal,
          activeCount: activeCount,
        ),
        if (!hasActiveGoal) ...[
          StaggeredFadeIn(
            index: 0,
            child: CreateGoalCard(onGoalAdded: onGoalAdded),
          ),
          const SizedBox(height: 16),
        ],
        if (goals.isEmpty)
          const EmptyGoalsState()
        else
          StaggeredFadeIn(
            index: hasActiveGoal ? 0 : 1,
            child: ClayCard(
              variant: ClayCardVariant.outlined,
              backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
              customPadding: const EdgeInsets.all(16),
              padding: ClayCardPadding.none,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: goals
                    .map((g) => GoalCard(
                          goal: g,
                          onToggleStatus: () => onToggleStatus(g),
                        ))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }
}

/// Section header above the goal list: anchors the screen with one line of
/// narrative so a single running goal no longer leaves the page feeling
/// empty. Tight below the header, generous above the cards (spacing check).
class _GoalsSectionHeader extends StatelessWidget {
  final bool hasActiveGoal;
  final int activeCount;

  const _GoalsSectionHeader({
    required this.hasActiveGoal,
    required this.activeCount,
  });

  @override
  Widget build(BuildContext context) {
    final headline = !hasActiveGoal
        ? 'Start your next goal'
        : activeCount == 1
            ? 'Your goal is on track'
            : '$activeCount goals running';
    final sub = !hasActiveGoal
        ? 'Set a target and track it here.'
        : 'Stay consistent — every check-in counts.';
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            headline,
            style: ClayTokens.titleMedium.copyWith(
              color: ClayTokens.clayDarkTextPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFFA0A4B8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton for the goal list: mirrors the hero card's mass (ring
/// placeholder + rows) so content does not jump when goals arrive.
class _GoalsSkeletonCard extends StatelessWidget {
  const _GoalsSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ClayCard(
        variant: ClayCardVariant.outlined,
        backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
        customPadding: const EdgeInsets.all(20),
        padding: ClayCardPadding.none,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 76,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
