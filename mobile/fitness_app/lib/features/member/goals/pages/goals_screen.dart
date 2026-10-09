import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../../features/shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/animations.dart'
    show StaggeredFadeIn, Shimmer;
import 'create_goal_card.dart';
import 'goal_card.dart';
import 'empty_goals_state.dart';

const bgDark = Color(0xFF0B0D1A);

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService().client
      .from('goals')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});

/// A goal is ongoing while its end date has not passed — regardless of DB
/// status — so the member cannot accidentally add a second one while the
/// window is still running. A missing/unparseable end date counts as ongoing
/// (safe side: the Create tab stays guarded). The date comparison matches
/// GoalCard's own isOverdue check so UI and predicate stay in sync.
bool _ongoing(Map<String, dynamic> g) {
  final end = DateTime.tryParse(g['end_date']?.toString() ?? '');
  return end == null || !end.isBefore(DateTime.now());
}

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);
    // Preserve the "one running goal at a time" rule: if any loaded goal is
    // still ongoing, the Create tab's form refuses a second insert. Falls back
    // to false while loading so the form stays usable on first paint.
    final hasActiveGoal = goalsAsync.valueOrNull?.any(_ongoing) ?? false;

    return CupertinoPageScaffold(
      backgroundColor: bgDark,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Goals'),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1 - Create a Goal: the form only.
                    _CreateTab(
                      hasActiveGoal: hasActiveGoal,
                      onGoalAdded: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Goal created'),
                            backgroundColor: const Color(0xFF22C55E),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        ref.invalidate(goalsProvider);
                        // Jump to the Goals tab so the new goal is visible.
                        _tabController.animateTo(1);
                      },
                    ),
                    // Tab 2 - Goals: the member's goals in glass-style cards.
                    goalsAsync.when(
                      data: (goals) => _GoalsTab(
                        goals: goals,
                        onToggleStatus: (g) async {
                          final currentStatus =
                              g['status'] as String? ?? 'active';
                          final newStatus = currentStatus == 'active'
                              ? 'completed'
                              : 'active';
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
                            // Self-notifications are denied by the
                            // notifications insert policy (user_id <>
                            // auth.uid()); a failed notification must
                            // never block the status refresh below.
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
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
                  ],
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

  /// Two-tab switcher: "Create a Goal" (the form) and "Goals" (the member's
  /// goals). A segmented pill so it reads as one glass system with the cards
  /// below it.
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withAlpha(18)),
        ),
        child: TabBar(
          controller: _tabController,
          isScrollable: false,
          labelPadding: EdgeInsets.zero,
          dividerColor: Colors.transparent,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [ClayTokens.clayPrimaryLight, ClayTokens.clayPrimary],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: ClayTokens.clayDarkTextSecondary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          tabs: const [
            Tab(text: 'Create a Goal'),
            Tab(text: 'Goals'),
          ],
        ),
      ),
    );
  }
}


/// "Create a Goal" tab — shows the create-goal form only. Adding a goal
/// refreshes the list and jumps to the Goals tab so the new goal is visible.
class _CreateTab extends StatelessWidget {
  final bool hasActiveGoal;
  final VoidCallback onGoalAdded;

  const _CreateTab({required this.hasActiveGoal, required this.onGoalAdded});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        StaggeredFadeIn(
          index: 0,
          child: CreateGoalCard(
            hasActiveGoal: hasActiveGoal,
            onGoalAdded: onGoalAdded,
          ),
        ),
      ],
    );
  }
}

/// "Goals" tab — the member's goals, each in a liquid-glass card. No create
/// form lives here: the Create a Goal tab owns that.
class _GoalsTab extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final void Function(Map<String, dynamic> goal) onToggleStatus;

  const _GoalsTab({
    required this.goals,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const EmptyGoalsState();
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        StaggeredFadeIn(
          index: 0,
          child: Column(
            children: goals
                .map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: GlassPanel(
                        padding: const EdgeInsets.all(12),
                        child: GoalCard(
                          goal: g,
                          onToggleStatus: () => onToggleStatus(g),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
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
