import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/utils/goal_progress.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../insight/pages/member_insight_page.dart'
    show memberInsightProvider, memberRiskProvider;
import '../../progress/pages/member_progress_page.dart'
    show memberProgressDataProvider;
import '../../progress/widgets/member_charts.dart';
import '../../progress/pages/member_progress_workouts.dart';
import '../../progress/pages/member_progress_nutrition.dart';
import '../../progress/pages/member_progress_checkins.dart';
import '../../progress/widgets/member_tab_widgets.dart';

/// The trainer's 4-tab Member Progress screen (Overview / Workouts /
/// Nutrition / Check-ins), opened by tapping a member anywhere in the trainer
/// app (Members list, Member Insight attention rows). The header shows the
/// member's avatar, name and code plus the retention-risk chip; each tab owns
/// its own independent date window.
class MemberProgressTabsPage extends ConsumerStatefulWidget {
  final String id;
  const MemberProgressTabsPage({super.key, required this.id});

  @override
  ConsumerState<MemberProgressTabsPage> createState() =>
      _MemberProgressTabsPageState();
}

class _MemberProgressTabsPageState
    extends ConsumerState<MemberProgressTabsPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insightAsync = ref.watch(memberInsightProvider(widget.id));
    final riskAsync = ref.watch(memberRiskProvider(widget.id));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildNavBar(),
              _buildHeader(insightAsync, riskAsync),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(id: widget.id, insightAsync: insightAsync),
                    WorkoutsTab(id: widget.id),
                    NutritionTab(id: widget.id),
                    CheckinsTab(id: widget.id),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 32,
              height: 32,
              child: Icon(
                Icons.chevron_left,
                color: ClayTokens.clayDarkTextPrimary,
                size: 22,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'Member Progress',
              textAlign: TextAlign.center,
              style: TextStyle(
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

  Widget _buildHeader(
    AsyncValue<Map<String, dynamic>> insightAsync,
    AsyncValue<String?> riskAsync,
  ) {
    final profile =
        insightAsync.valueOrNull?['profile'] as Map<String, dynamic>?;
    final name = (profile?['full_name'] as String?)?.trim();
    final displayName = (name == null || name.isEmpty) ? 'Member' : name;
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Row(
        children: [
          ClayAvatar(
            imageUrl: profile?['avatar_url'] as String?,
            initials: initials.isEmpty ? '?' : initials,
            size: ClayAvatarSize.md,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  (profile?['code'] as String?)?.isNotEmpty == true
                      ? 'Code ${profile?['code']}'
                      : 'Trainer member',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          const _StreakFire(),
          const SizedBox(width: 6),
          _HeaderRiskChip(riskAsync: riskAsync),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      isScrollable: false,
      labelColor: Colors.white,
      unselectedLabelColor: ClayTokens.clayDarkTextTertiary,
      indicatorColor: ClayTokens.clayPrimary,
      indicatorWeight: 2.5,
      labelStyle: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
      tabs: const [
        Tab(text: 'Overview'),
        Tab(text: 'Workouts'),
        Tab(text: 'Nutrition'),
        Tab(text: 'Check-ins'),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Streak fire (animated gif) shown to the left of the retention-risk chip
// ---------------------------------------------------------------------------

class _StreakFire extends StatelessWidget {
  const _StreakFire();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/animations/fire.gif',
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.local_fire_department,
        size: 20,
        color: ClayTokens.clayWarning,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Retention-risk chip (mirrors _RiskChip on the Member Insight screen)
// ---------------------------------------------------------------------------

class _HeaderRiskChip extends StatelessWidget {
  final AsyncValue<String?> riskAsync;
  const _HeaderRiskChip({required this.riskAsync});

  @override
  Widget build(BuildContext context) {
    return riskAsync.when(
      loading: () => const SkeletonBox(width: 60, height: 22, borderRadius: 11),
      error: (_, __) => const SizedBox.shrink(),
      data: (label) {
        if (label == null || label.isEmpty) return const SizedBox.shrink();
        final color = label == 'high'
            ? const Color(0xFFFF453A)
            : label == 'medium'
                ? const Color(0xFFFF9500)
                : const Color(0xFF30D158);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withAlpha(70)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 5),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}


// ---------------------------------------------------------------------------
// Overview tab: goal summary + This Week / This Month / Growth charts
// ---------------------------------------------------------------------------

class _OverviewTab extends ConsumerWidget {
  final String id;
  final AsyncValue<Map<String, dynamic>> insightAsync;

  const _OverviewTab({required this.id, required this.insightAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(memberProgressDataProvider(id));

    return progressAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SizedBox(height: 12),
            SkeletonCard(height: 150),
            SkeletonCard(height: 150),
          ],
        ),
      ),
      error: (e, _) => MemberTabError(message: '$e'),
      data: (progress) {
        final weekCounts = (progress['weekCounts'] as List).cast<int>();
        final maxWeek = progress['maxWeek'] as int;
        final monthlyCounts = (progress['monthlyCounts'] as List).cast<int>();
        final monthlyWeights =
            (progress['monthlyWeights'] as List).cast<double?>();
        final goal =
            insightAsync.valueOrNull?['goal'] as Map<String, dynamic>?;
        final measurements =
            (insightAsync.valueOrNull?['measurements'] as List?)
                    ?.cast<Map<String, dynamic>>() ??
                const <Map<String, dynamic>>[];

        return ListView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
          physics: const ClampingScrollPhysics(),
          children: [
            if (goal != null)
              _GoalSummaryCard(goal: goal, measurements: measurements)
            else
              const _NoGoalCard(),
            const SizedBox(height: 10),
            MemberWeekChart(weekCounts: weekCounts, maxCount: maxWeek),
            const SizedBox(height: 10),
            MemberMonthChart(monthlyCounts: monthlyCounts),
            const SizedBox(height: 10),
            MemberGrowthChart(monthlyWeights: monthlyWeights),
          ],
        );
      },
    );
  }
}


/// Compact goal summary: title, journey progress — the same number the Member
/// Insight goal card shows, so both screens agree.
class _GoalSummaryCard extends StatelessWidget {
  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> measurements;

  const _GoalSummaryCard({required this.goal, required this.measurements});

  @override
  Widget build(BuildContext context) {
    final goalType = (goal['goal_type'] as String?) ?? '';
    final title = (goal['title'] as String?)?.trim();
    final displayTitle = (title == null || title.isEmpty)
        ? (goalType.isEmpty ? 'Goal' : goalType)
        : title;
    final baseline = (goal['current_value'] as num?)?.toDouble();
    final target = (goal['target_value'] as num?)?.toDouble();
    final live = measurements.isNotEmpty
        ? (measurements.first['weight_kg'] as num?)?.toDouble()
        : null;
    final calc = computeGoalProgress(
      baseline: baseline,
      target: target,
      live: live,
      goalType: goalType,
    );
    final pct = calc.pct.clamp(0.0, 100.0);
    final remaining = calc.remaining;

    final startDate =
        DateTime.tryParse(goal['start_date']?.toString() ?? '') ??
        DateTime.now();
    final endDate =
        DateTime.tryParse(goal['end_date']?.toString() ?? '') ??
        DateTime.now().add(const Duration(days: 30));
    final now = DateTime.now();
    final totalDays = endDate.difference(startDate).inDays.clamp(1, 3650);
    final elapsedDays = now.difference(startDate).inDays.clamp(0, totalDays);
    final timeProgress = (elapsedDays / totalDays).clamp(0.0, 1.0);
    final daysRemaining = (endDate.difference(now).inHours / 24).ceil();
    final displayDays = daysRemaining < 0 ? 0 : daysRemaining;
    final isOverdue = endDate.isBefore(now);
    final status = goal['status'] as String? ?? 'active';
    final isCompleted =
        status == 'completed' || (isOverdue && status == 'active');

    final unit = goalType.toLowerCase() == 'lose weight' ||
            goalType.toLowerCase() == 'gain muscle' ||
            goalType.toLowerCase() == 'maintain weight'
        ? 'kg'
        : '';
    final currentDisplay = goalType.isNotEmpty ? (live ?? baseline) : baseline;
    final remainingDisplay = remaining == null
        ? null
        : (remaining < 0 ? 0.0 : remaining);

    final ringColor = isCompleted
        ? const Color(0xFF30D158)
        : ClayTokens.clayPrimaryLight;
    final daysColor = isCompleted
        ? const Color(0xFF30D158)
        : isOverdue || daysRemaining <= 3
        ? const Color(0xFFFF453A)
        : daysRemaining <= 7
        ? ClayTokens.clayWarning
        : const Color(0xFF30D158);

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row: icon + title/goal-type + status pill.
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary.withAlpha(30),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  _goalIcon(goalType),
                  color: ClayTokens.clayPrimaryLight,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                        color: Colors.white,
                      ),
                    ),
                    if (goalType.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        goalType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                          color: ClayTokens.clayDarkTextSecondary,
                        ),
                      ),
                    ],
                    if (target != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        'Target: ${target.toStringAsFixed(1)} $unit',
                        style: TextStyle(
                          fontSize: 12,
                          color: ClayTokens.clayDarkTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: (isCompleted
                          ? const Color(0xFF30D158)
                          : ClayTokens.clayPrimaryLight)
                      .withAlpha(28),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: (isCompleted
                            ? const Color(0xFF30D158)
                            : ClayTokens.clayPrimaryLight)
                        .withAlpha(90),
                  ),
                ),
                child: Text(
                  isCompleted
                      ? 'COMPLETED'
                      : (isOverdue ? 'EXPIRED' : 'IN PROGRESS'),
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: isCompleted
                        ? const Color(0xFF30D158)
                        : ClayTokens.clayPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _GoalRing(pct: pct, ringColor: ringColor),
          const SizedBox(height: 16),
          // Target / Current / To-go stat row.
          Row(
            children: [
              _GoalStatCell(
                label: 'Target',
                value: target != null
                    ? '${target.toStringAsFixed(1)} $unit'
                    : '—',
                accent: false,
              ),
              _GoalStatCell(
                label: 'Current',
                value: currentDisplay != null
                    ? '${currentDisplay.toStringAsFixed(1)} $unit'
                    : '—',
                accent: false,
              ),
              _GoalStatCell(
                label: 'To go',
                value: remainingDisplay != null
                    ? '${remainingDisplay.toStringAsFixed(1)} $unit'
                    : '—',
                accent: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _DaysBanner(
            displayDays: displayDays,
            daysColor: daysColor,
            dateRange:
                '${_shortDate(startDate)} – ${_shortDate(endDate)}, '
                '${endDate.year}',
          ),
          const SizedBox(height: 14),
          // Day-of-window progress bar.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: timeProgress,
              minHeight: 8,
              backgroundColor: Colors.white.withAlpha(18),
              valueColor: AlwaysStoppedAnimation<Color>(
                isCompleted ? const Color(0xFF30D158) : ClayTokens.clayPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isOverdue && !isCompleted
                ? 'Ended ${_shortDate(endDate)}, ${endDate.year}'
                : 'Day $elapsedDays of $totalDays',
            style: TextStyle(
              fontSize: 11.5,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  IconData _goalIcon(String goalType) {
    switch (goalType.toLowerCase()) {
      case 'lose weight':
        return Icons.trending_down_rounded;
      case 'gain muscle':
        return Icons.fitness_center_rounded;
      case 'maintain weight':
        return Icons.balance_rounded;
      default:
        return Icons.flag_rounded;
    }
  }
}

class _NoGoalCard extends StatelessWidget {
  const _NoGoalCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Icon(
            Icons.flag_outlined,
            size: 18,
            color: ClayTokens.clayDarkTextTertiary,
          ),
          const SizedBox(width: 10),
          Text(
            'No running goal yet',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated circular "X% of target" ring for the goal hero card.
class _GoalRing extends StatelessWidget {
  final double pct;
  final Color ringColor;
  const _GoalRing({required this.pct, required this.ringColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 132,
        height: 132,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: pct / 100.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => CircularProgressIndicator(
                  value: value,
                  backgroundColor: ClayTokens.clayPrimary.withAlpha(40),
                  color: ringColor,
                  strokeWidth: 11,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${pct.round()}%',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'of target',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One TARGET / CURRENT / TO-GO cell in the goal hero card.
class _GoalStatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _GoalStatCell({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: accent ? ClayTokens.clayPrimaryLight : Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Days-remaining banner tinted by urgency, matching the member GoalCard.
class _DaysBanner extends StatelessWidget {
  final int displayDays;
  final Color daysColor;
  final String dateRange;

  const _DaysBanner({
    required this.displayDays,
    required this.daysColor,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: daysColor.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: daysColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: daysColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.calendar_today_rounded,
              size: 17,
              color: daysColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$displayDays',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: daysColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        displayDays == 1 ? 'day left' : 'days left',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: daysColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


