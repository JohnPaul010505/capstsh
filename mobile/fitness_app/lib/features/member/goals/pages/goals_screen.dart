import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/glass_confirm_dialog.dart';
import '../../../shared/widgets/animations.dart' show StaggeredFadeIn, Shimmer;
import 'create_goal_card.dart';
import 'goal_card.dart';
import 'empty_goals_state.dart';
import '../services/goal_home_widget.dart';

const bgDark = Color(0xFF0B0D1A);

final goalsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, requestedUserId) async {
      final client = SupabaseClientService().client;
      final activeUserId = ref.watch(activeUserIdProvider);
      final authUserId = client.auth.currentUser?.id;
      if (requestedUserId.isEmpty ||
          requestedUserId != activeUserId ||
          requestedUserId != authUserId) {
        throw Exception('Signed out — please log in again.');
      }
      final response = await client
          .from('goals')
          .select()
          .eq('member_id', requestedUserId)
          .order('created_at', ascending: false);
      return response;
    });

/// A goal is ongoing while its end date has not passed — regardless of DB
/// status — so the member cannot accidentally add a second one while the
/// window is still running. A missing/unparseable end date counts as ongoing
/// (safe side: the Create tab stays guarded). The date comparison matches
/// GoalCard's own isOverdue check so UI and predicate stay in sync.
bool _ongoing(Map<String, dynamic> g) {
  if ((g['status'] as String? ?? 'active') != 'active') return false;
  final end = DateTime.tryParse(g['end_date']?.toString() ?? '');
  return end == null || !end.isBefore(DateTime.now());
}

bool _isHistoryGoal(Map<String, dynamic> goal) {
  if ((goal['status'] as String? ?? 'active') != 'active') return true;
  final end = DateTime.tryParse(goal['end_date']?.toString() ?? '');
  return end != null && end.isBefore(DateTime.now());
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
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memberId = ref.watch(activeUserIdProvider);
    final goalsAsync = memberId == null
        ? const AsyncValue<List<Map<String, dynamic>>>.data([])
        : ref.watch(goalsProvider(memberId));
    // Preserve the "one running goal at a time" rule: if any loaded goal is
    // still ongoing, the Create tab's form refuses a second insert. Falls back
    // to false while loading so the form stays usable on first paint.
    final hasActiveGoal = goalsAsync.valueOrNull?.any(_ongoing) ?? false;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                        if (memberId != null) {
                          ref.invalidate(goalsProvider(memberId));
                        }
                        // Jump to the Goals tab so the new goal is visible.
                        _tabController.animateTo(1);
                      },
                    ),
                    // Tab 2 - Goals: the member's goals in glass-style cards.
                    goalsAsync.when(
                      data: (goals) => _GoalsTab(
                        goals: goals.where((g) => !_isHistoryGoal(g)).toList(),
                        history: false,
                        onCreate: () => _tabController.animateTo(0),
                        onCancel: (g) async {
                          final confirmed = await showGlassConfirmDialog(
                            context,
                            title: 'Cancel this goal?',
                            message:
                                'You can create a new goal after cancelling this one.',
                            keepLabel: 'Keep goal',
                            confirmLabel: 'Cancel goal',
                          );
                          if (confirmed == true) {
                            await SupabaseClientService().client
                                .from('goals')
                                .update({'status': 'cancelled'})
                                .eq('id', g['id']);
                            await GoalHomeWidget.syncForCurrentMember();
                            if (memberId != null) {
                              ref.invalidate(goalsProvider(memberId));
                            }
                            _tabController.animateTo(2);
                          }
                        },
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
                          await GoalHomeWidget.syncForCurrentMember();
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
                          if (memberId != null) {
                            ref.invalidate(goalsProvider(memberId));
                          }
                          _tabController.animateTo(
                            newStatus == 'completed' ? 2 : 1,
                          );
                        },
                      ),
                      loading: () => ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
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
                    // Tab 3 - completed and cancelled goals.
                    goalsAsync.when(
                      data: (goals) => _GoalsTab(
                        goals: goals.where(_isHistoryGoal).toList(),
                        history: true,
                        onCreate: () => _tabController.animateTo(0),
                        onCancel: (_) {},
                        onToggleStatus: (g) async {
                          await SupabaseClientService().client
                              .from('goals')
                              .update({'status': 'active'})
                              .eq('id', g['id']);
                          await GoalHomeWidget.syncForCurrentMember();
                          if (memberId != null) {
                            ref.invalidate(goalsProvider(memberId));
                          }
                          _tabController.animateTo(1);
                        },
                      ),
                      loading: () => ListView(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
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
                          style: const TextStyle(
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
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayDarkTextPrimary,
            ),
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

  /// Three-tab switcher for creating, tracking, and reviewing goals.
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: ClayTokens.clayDarkSurface.withAlpha(120),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: ClayColors.isLightMode
                ? ClayTokens.clayPrimary.withAlpha(45)
                : Colors.white.withAlpha(18),
          ),
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
            Tab(text: 'History'),
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
  final bool history;
  final VoidCallback onCreate;
  final void Function(Map<String, dynamic> goal) onToggleStatus;
  final void Function(Map<String, dynamic> goal) onCancel;

  const _GoalsTab({
    required this.goals,
    required this.history,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      if (!history) return EmptyGoalsState(onAction: onCreate);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: GlassPanel(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(CupertinoIcons.clock, color: Color(0xFFA855F7), size: 38),
                const SizedBox(height: 12),
                Text(
                  'No goal history yet',
                  style: TextStyle(
                    color: ClayTokens.clayDarkTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Completed and cancelled goals will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        StaggeredFadeIn(
          index: 0,
          child: Column(
            children: goals
                .map(
                  (g) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GlassPanel(
                      padding: const EdgeInsets.all(12),
                      child: GoalCard(
                        goal: g,
                        onToggleStatus: () => onToggleStatus(g),
                        onCancel:
                            (g['status'] as String? ?? 'active') == 'active'
                            ? () => onCancel(g)
                            : null,
                      ),
                    ),
                  ),
                )
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
      child: MemberGlassCard(
        padding: const EdgeInsets.all(20),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: ClayTokens.hairline.withAlpha(25),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 18,
                        width: 150,
                        decoration: BoxDecoration(
                          color: ClayTokens.hairline.withAlpha(25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 90,
                        decoration: BoxDecoration(
                          color: ClayTokens.hairline.withAlpha(18),
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
                    color: ClayTokens.hairline.withAlpha(25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: glassRimSoft(const Color(0xFF2C2C2E)),
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(height: 16),
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: ClayTokens.hairline.withAlpha(18),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
