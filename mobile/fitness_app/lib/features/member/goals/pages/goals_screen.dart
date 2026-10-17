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
import 'create_food_goal_card.dart';
import 'goal_card.dart';
import 'food_goal_card.dart';
import 'empty_goals_state.dart';
import '../services/goal_home_widget.dart';

const bgDark = Color(0xFF0B0D1A);

/// Which goal family the Goals screen is showing. The burger button switches
/// between them; each has its own Create / Goals / History tabs, its own
/// "one running goal at a time" guard, and its own card.
enum _GoalMode { workout, food }


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

/// Category of a goal row. Rows predating migration 0049 (and any with a null
/// value) are treated as workout goals, matching the column default.
bool _isFoodGoal(Map<String, dynamic> goal) =>
    (goal['goal_category'] as String? ?? 'workout') == 'food';


class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Which goal family is showing. Workout is the default so existing members
  /// land on the exact screen they know. Local widget state only — never shared
  /// across users.
  _GoalMode _mode = _GoalMode.workout;

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
    // "One running goal at a time", scoped to the ACTIVE category so a food
    // goal and a workout goal can coexist without blocking each other. Falls
    // back to false while loading so the form stays usable on first paint.
    final isFood = _mode == _GoalMode.food;
    final hasActiveGoal =
        goalsAsync.valueOrNull?.any((g) => _ongoing(g) && _isFoodGoal(g) == isFood) ??
        false;

    return CupertinoPageScaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isFood ? 'Food Goals' : 'Goals'),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1 - Create a Goal: the form only.
                    _CreateTab(
                      isFood: isFood,
                      hasActiveGoal: hasActiveGoal,
                      onGoalAdded: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isFood ? 'Food goal created' : 'Goal created',
                            ),
                            backgroundColor: const Color(0xFF22C55E),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        if (memberId != null) {
                          ref.invalidate(goalsProvider(memberId));
                        }
                        // Keep the matching launcher widget in step: the food
                        // widget mirrors the running food goal, the workout
                        // widget the weight goal.
                        if (isFood) {
                          GoalHomeWidget.syncFoodForCurrentMember();
                        } else {
                          GoalHomeWidget.syncForCurrentMember();
                        }
                        // Jump to the Goals tab so the new goal is visible.
                        _tabController.animateTo(1);
                      },
                    ),
                    // Tab 2 - Goals: the member's goals in glass-style cards.
                    goalsAsync.when(
                      data: (goals) => _GoalsTab(
                        isFood: isFood,
                        goals: goals
                            .where((g) => !_isHistoryGoal(g) && _isFoodGoal(g) == isFood)
                            .toList(),
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
                            if (isFood) {
                              await GoalHomeWidget.syncFoodForCurrentMember();
                            } else {
                              await GoalHomeWidget.syncForCurrentMember();
                            }
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
                        isFood: isFood,
                        goals: goals
                            .where((g) => _isHistoryGoal(g) && _isFoodGoal(g) == isFood)
                            .toList(),
                        history: true,
                        onCreate: () => _tabController.animateTo(0),
                        onCancel: (_) {},
                        onToggleStatus: (g) async {
                          await SupabaseClientService().client
                              .from('goals')
                              .update({'status': 'active'})
                              .eq('id', g['id']);
                          if (isFood) {
                            await GoalHomeWidget.syncFoodForCurrentMember();
                          } else {
                            await GoalHomeWidget.syncForCurrentMember();
                          }
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
          // Burger button: switches between the Workout and Food goal families.
          // PopupMenuButton anchors the dropdown directly beneath this button
          // (top-right), matching the reference menu instead of floating it at
          // a page-global offset.
          PopupMenuButton<String>(
            tooltip: 'Switch goal type',
            position: PopupMenuPosition.under,
            color: ClayColors.isLightMode
                ? Colors.white
                : ClayTokens.clayDarkSurface,
            // The menu hangs directly beneath the burger, flush with the
            // button's end edge, and the shape's arrow pokes up into the
            // button itself — mirroring the reference menu.
            shape: const _MenuArrowShape(),
            offset: const Offset(0, 6),
            icon: Icon(
              CupertinoIcons.bars,
              size: 20,
              color: ClayTokens.clayDarkTextPrimary,
            ),
            onSelected: (value) {
              final next =
                  value == 'food' ? _GoalMode.food : _GoalMode.workout;
              if (next != _mode) setState(() => _mode = next);
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'workout',
                child: _ModeMenuItem(
                  label: 'Workout Goals',
                  icon: CupertinoIcons.flame,
                  selected: _mode == _GoalMode.workout,
                ),
              ),
              PopupMenuItem<String>(
                value: 'food',
                child: _ModeMenuItem(
                  label: 'Food Goals',
                  icon: CupertinoIcons.cube_box,
                  selected: _mode == _GoalMode.food,
                ),
              ),
            ],
          ),
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
  final bool isFood;
  final bool hasActiveGoal;
  final VoidCallback onGoalAdded;

  const _CreateTab({
    required this.isFood,
    required this.hasActiveGoal,
    required this.onGoalAdded,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        StaggeredFadeIn(
          index: 0,
          child: isFood
              ? CreateFoodGoalCard(
                  hasActiveGoal: hasActiveGoal,
                  onGoalAdded: onGoalAdded,
                )
              : CreateGoalCard(
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
  final bool isFood;
  final List<Map<String, dynamic>> goals;
  final bool history;
  final VoidCallback onCreate;
  final void Function(Map<String, dynamic> goal) onToggleStatus;
  final void Function(Map<String, dynamic> goal) onCancel;

  const _GoalsTab({
    required this.isFood,
    required this.goals,
    required this.history,
    required this.onCreate,
    required this.onToggleStatus,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      if (!history) {
        if (isFood) {
          return _FoodEmptyState(onAction: onCreate);
        }
        return EmptyGoalsState(onAction: onCreate);
      }
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
                    child: MemberGlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: BorderRadius.circular(16),
                      darkBuilder: (child) => Padding(
                        padding: const EdgeInsets.all(12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: ClayTokens.clayDarkCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withAlpha(30)),
                          ),
                          child: child,
                        ),
                      ),
                      child: isFood
                          ? FoodGoalCard(
                              goal: g,
                              onCancel:
                                  (g['status'] as String? ?? 'active') == 'active'
                                  ? () => onCancel(g)
                                  : null,
                            )
                          : GoalCard(
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

/// Empty state for the Food goals tab — mirrors EmptyGoalsState's glass panel
/// but speaks to daily calorie targets instead of weight.
class _FoodEmptyState extends StatelessWidget {
  final VoidCallback? onAction;

  const _FoodEmptyState({this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: MemberGlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimary.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.flame_fill,
                    color: ClayTokens.clayPrimary,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Food Goals Yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Set a daily calorie target and track it against your food intake!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ClayTokens.clayDarkTextSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(14),
                    onPressed: onAction,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          CupertinoIcons.plus,
                          color: Color(0xFFFFFFFF),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Create your first food goal',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFFFFFF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One row in the burger menu: icon + label, with a checkmark on the active
/// family. Uses the same glass ink as the rest of the Goals screen.
class _ModeMenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;

  const _ModeMenuItem({
    required this.label,
    required this.icon,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: selected
              ? ClayTokens.clayPrimaryLight
              : ClayTokens.clayDarkTextSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected
                  ? ClayTokens.clayDarkTextPrimary
                  : ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ),
        if (selected)
          Icon(
            CupertinoIcons.checkmark_circle_fill,
            color: ClayTokens.clayPrimaryLight,
            size: 16,
          ),
      ],
    );
  }
}

/// Popup menu shape with an arrow notch at the top that points up at the
/// burger button. The menu's right edge always aligns with the button's
/// right edge (the button is the last child of a header Row padded 8px, so
/// Flutter right-aligns the menu; the route's horizontal padding is 0), and
/// the button is a 48px IconButton - its centre is exactly 24px from the
/// menu's right edge, so the tip is computed from the actual rect at paint
/// time and stays exact for any menu width.
/// — the menu hangs off the button like a little speech bubble, exactly like
/// the reference menu.
class _MenuArrowShape extends ShapeBorder {
  const _MenuArrowShape();

  /// How far the arrow pokes above the menu's rounded rectangle.
  static const double _arrowHeight = 12.0;

  /// Half-width of the arrow's base along the menu's top edge.
  static const double _arrowHalfWidth = 9.0;

  static const double _edgeRadius = 14.0;

  /// Distance from the menu's right edge to the arrow's centre line
  /// (half of the 48px burger button).
  static const double _arrowFromRight = 24.0;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRect(rect);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final topY = rect.top + _arrowHeight;
    final tipX = rect.right - _arrowFromRight;
    return Path()
      // Top edge: rounded top-left corner, up the arrow's left slope, down
      // the right slope, then along to the top-right corner.
      ..moveTo(rect.left + _edgeRadius, topY)
      ..lineTo(tipX - _arrowHalfWidth, topY)
      ..lineTo(tipX, topY - _arrowHeight)
      ..lineTo(tipX + _arrowHalfWidth, topY)
      ..lineTo(rect.right - _edgeRadius, topY)
      ..quadraticBezierTo(rect.right, topY, rect.right, topY + _edgeRadius)
      // Right edge + bottom-right corner.
      ..lineTo(rect.right, rect.bottom - _edgeRadius)
      ..quadraticBezierTo(
        rect.right,
        rect.bottom,
        rect.right - _edgeRadius,
        rect.bottom,
      )
      // Bottom edge + bottom-left corner.
      ..lineTo(rect.left + _edgeRadius, rect.bottom)
      ..quadraticBezierTo(
        rect.left,
        rect.bottom,
        rect.left,
        rect.bottom - _edgeRadius,
      )
      // Left edge back up to the rounded top-left corner.
      ..lineTo(rect.left, topY + _edgeRadius)
      ..quadraticBezierTo(rect.left, topY, rect.left + _edgeRadius, topY)
      ..close();
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {}

  @override
  ShapeBorder scale(double t) => this;
}

