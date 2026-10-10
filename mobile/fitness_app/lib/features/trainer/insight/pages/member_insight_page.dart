import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/services/prediction_service.dart';
import '../../../shared/utils/goal_progress.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../progress/pages/member_progress_page.dart'
    show memberProgressDataProvider;

/// Member Insight detail: the ONE screen a trainer opens from the dashboard
/// search or a Members-list row. Shows the member's profile, retention
/// risk, running goal with the ACCURATE journey percentage
/// (computeGoalProgress — the same formula the member's own Goals screen
/// uses, so trainer and member can never disagree), this week's completed
/// sessions, recent check-ins, and weight history.
final memberInsightProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, memberId) async {
  final client = SupabaseClientService().client;
  final results = await Future.wait([
    client
        .from('profiles')
        .select('id, full_name, email, avatar_url, code')
        .eq('id', memberId)
        .single(),
    // Members create goals as 'in_progress' while seeds use 'active'; a
    // running goal is either. Newest first → the first row is the goal.
    client
        .from('goals')
        .select(
          'title, goal_type, target_value, current_value, start_date, '
          'end_date, status',
        )
        .eq('member_id', memberId)
        .inFilter('status', ['active', 'in_progress'])
        .order('created_at', ascending: false),
    // Newest-first: first row = live weight, next rows feed the trend list.
    client
        .from('body_measurements')
        .select('weight_kg, height_cm, measured_at')
        .eq('member_id', memberId)
        .order('measured_at', ascending: false)
        .limit(8),
    client
        .from('attendance')
        .select('check_in_time')
        .eq('member_id', memberId)
        .order('check_in_time', ascending: false)
        .limit(10),
  ]);

  final profile = results[0] as Map<String, dynamic>;
  final goals = results[1] as List;
  final measurements = (results[2] as List).cast<Map<String, dynamic>>();
  final checkins = (results[3] as List).cast<Map<String, dynamic>>();

  return {
    'profile': profile,
    'goal': goals.isEmpty ? null : goals.first as Map<String, dynamic>,
    'measurements': measurements,
    'checkins': checkins,
  };
});

/// Retention risk for ONE member, fetched OFF the critical path (the AI
/// service sits behind the dev tunnel and must never gate the screen).
/// `null` = no forecast available (new member / service down) — the chip
/// simply hides; the rest of the screen renders regardless.
final memberRiskProvider = FutureProvider.autoDispose.family<String?, String>(
  (ref, memberId) async {
    try {
      final forecast = await PredictionService()
          .getForecast(memberId)
          .timeout(const Duration(seconds: 5));
      return forecast.retention?.riskLabel;
    } catch (_) {
      return null;
    }
  },
);

class MemberInsightPage extends ConsumerWidget {
  final String id;
  const MemberInsightPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(memberInsightProvider(id));
    final riskAsync = ref.watch(memberRiskProvider(id));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInsightNavBar(context),
              Expanded(
                child: dataAsync.when(
                  data: (data) {
                    final profile =
                        data['profile'] as Map<String, dynamic>;
                    final goal = data['goal'] as Map<String, dynamic>?;
                    final measurements = (data['measurements'] as List)
                        .cast<Map<String, dynamic>>();
                    final checkins = (data['checkins'] as List)
                        .cast<Map<String, dynamic>>();

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        _Header(profile: profile, riskAsync: riskAsync),
                        const SizedBox(height: 10),
                        if (goal != null)
                          _GoalSection(goal: goal, measurements: measurements)
                        else
                          const _NoGoalCard(),
                        const SizedBox(height: 10),
                        _WeekSessionSection(id: id),
                        const SizedBox(height: 10),
                        _CheckinsSection(checkins: checkins),
                        const SizedBox(height: 10),
                        _WeightSection(measurements: measurements),
                        const SizedBox(height: 10),
                        _FullProgressLink(id: id),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14),
                    child: Column(
                      children: [
                        SizedBox(height: 8),
                        SkeletonCard(height: 90),
                        SkeletonCard(height: 220),
                        SkeletonCard(height: 120),
                        SkeletonCard(height: 140),
                      ],
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.person_crop_circle,
                          color: ClayTokens.clayDarkTextTertiary,
                          size: 34,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load this member',
                          style: ClayTokens.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: ClayTokens.clayDarkTextSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$e',
                          textAlign: TextAlign.center,
                          style: ClayTokens.bodySmall.copyWith(
                            fontSize: 11,
                            color: ClayTokens.clayDarkTextTertiary,
                          ),
                        ),
                      ],
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
}

Widget _buildInsightNavBar(BuildContext context) {
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
          onTap: () => context.pop(),
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
            'Member Insight',
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

/// Header card: avatar, name, member code/email, and the retention-risk
/// chip that pops in when the forecast lands (hidden when unavailable).
class _Header extends StatelessWidget {
  final Map<String, dynamic> profile;
  final AsyncValue<String?> riskAsync;

  const _Header({required this.profile, required this.riskAsync});

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] as String? ?? 'Member';
    final email = profile['email'] as String? ?? '';
    final code = profile['code'] as String? ?? '';
    final avatarUrl = profile['avatar_url'] as String?;
    final initials = name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join();
    final subtitle = [
      if (code.isNotEmpty) code,
      if (email.isNotEmpty) email,
    ].join('  ·  ');

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          ClayAvatar(
            imageUrl: avatarUrl,
            initials: initials,
            size: ClayAvatarSize.lg,
            backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ClayTokens.titleLarge.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                    letterSpacing: -0.24,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ClayTokens.bodySmall.copyWith(
                      fontSize: 11,
                      color: ClayTokens.clayDarkTextTertiary,
                      letterSpacing: -0.08,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _RiskChip(riskAsync: riskAsync),
        ],
      ),
    );
  }
}

/// HIGH / MEDIUM / LOW retention chip (iOS system colors, same treatment
/// the old Members list used). Shimmers while the forecast loads and hides
/// itself on error / not-enough-data — the chip must never break the screen.
class _RiskChip extends StatelessWidget {
  final AsyncValue<String?> riskAsync;

  const _RiskChip({required this.riskAsync});

  @override
  Widget build(BuildContext context) {
    return riskAsync.when(
      loading: () => const SkeletonBox(width: 84, height: 24, borderRadius: 12),
      error: (_, __) => const SizedBox.shrink(),
      data: (label) {
        if (label == null || label.isEmpty) return const SizedBox.shrink();
        final color = label == 'high'
            ? const Color(0xFFFF453A)
            : label == 'medium'
                ? const Color(0xFFFF9500)
                : const Color(0xFF30D158);
        return Semantics(
          label: 'Retention risk: $label',
          child: Container(
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
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  'RISK ${label.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Running-goal card: title, type, target, the ACCURATE journey ring
/// (computeGoalProgress — matches the member's own Goals screen), current /
/// to-go / day-of-goal stats, and the days-left banner with urgency tint.
class _GoalSection extends StatelessWidget {
  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> measurements; // newest-first

  const _GoalSection({required this.goal, required this.measurements});

  static const _green = Color(0xFF30D158);
  static const _amber = Color(0xFFFF9F0A);
  static const _red = Color(0xFFFF453A);

  @override
  Widget build(BuildContext context) {
    final title = goal['title'] as String? ?? 'Untitled Goal';
    final goalType = goal['goal_type'] as String? ?? '';
    final target = (goal['target_value'] as num?)?.toDouble();
    final baseline = (goal['current_value'] as num?)?.toDouble();
    final status = goal['status'] as String? ?? 'active';
    final start = DateTime.tryParse(goal['start_date']?.toString() ?? '');
    final end = DateTime.tryParse(goal['end_date']?.toString() ?? '');

    final live = measurements.isEmpty
        ? null
        : (measurements.first['weight_kg'] as num?)?.toDouble();

    // ONE formula, shared with the member's Goals screen.
    final calc = computeGoalProgress(
      baseline: baseline,
      target: target,
      live: live,
      goalType: goalType,
    );

    final now = DateTime.now();
    final startDate = start ??
        (end != null ? end.subtract(const Duration(days: 30)) : now);
    final endDate = end ?? now.add(const Duration(days: 30));
    final totalDays = endDate.difference(startDate).inDays.clamp(1, 3650);
    final elapsedDays = now.difference(startDate).inDays.clamp(0, totalDays);
    final daysRemaining = ((endDate.difference(now).inHours) / 24).ceil();
    final displayDays = daysRemaining < 0 ? 0 : daysRemaining;
    final isOverdue = endDate.isBefore(now);
    final isCompleted = status == 'completed';
    final daysColor = isCompleted
        ? _green
        : isOverdue || displayDays <= 3
            ? _red
            : displayDays <= 7
                ? _amber
                : _green;
    final statusLabel = isCompleted
        ? 'COMPLETED'
        : isOverdue
            ? 'EXPIRED'
            : 'IN PROGRESS';
    final statusColor = isCompleted
        ? _green
        : isOverdue
            ? ClayTokens.clayDarkTextTertiary
            : ClayTokens.clayPrimaryLight;

    final isWeightGoal = goalType.toLowerCase() == 'lose weight' ||
        goalType.toLowerCase() == 'gain muscle' ||
        goalType.toLowerCase() == 'maintain weight';
    final unit = isWeightGoal ? 'kg' : '';
    final currentDisplay = goalType.isNotEmpty ? (live ?? baseline) : baseline;
    final remainingRaw = calc.remaining;
    final remainingDisplay =
        remainingRaw == null ? null : (remainingRaw < 0 ? 0.0 : remainingRaw);
    final dayOfGoal = (elapsedDays + 1).clamp(1, totalDays);
    final dateRange =
        '${DateFormat('MMM d').format(startDate)} – ${DateFormat('MMM d').format(endDate)}';

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimaryLight.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _goalIcon(goalType),
                  size: 18,
                  color: ClayTokens.clayPrimaryLight,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      goalType.isNotEmpty
                          ? '${goalType.toUpperCase()}  ·  Target: '
                              '${target?.toStringAsFixed(1) ?? '—'} $unit'
                          : 'SEEDED GOAL',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextTertiary,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withAlpha(90)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Semantics(
              label:
                  'Goal progress ${calc.pct.toStringAsFixed(0)} percent of target',
              child: SizedBox(
                width: 128,
                height: 128,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: calc.fraction),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 128,
                        height: 128,
                        child: CircularProgressIndicator(
                          value: value,
                          backgroundColor:
                              ClayTokens.clayPrimaryLight.withAlpha(28),
                          color: isCompleted
                              ? _green
                              : ClayTokens.clayPrimaryLight,
                          strokeWidth: 11,
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${(value * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'of target',
                            style: TextStyle(
                              fontSize: 10,
                              color: ClayTokens.clayDarkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              _StatCell(
                label: 'CURRENT',
                value: currentDisplay == null
                    ? '—'
                    : '${currentDisplay.toStringAsFixed(1)} $unit',
              ),
              _StatCell(
                label: 'TO GO',
                value: remainingDisplay == null
                    ? '—'
                    : '${remainingDisplay.toStringAsFixed(1)} $unit',
                accent: true,
              ),
              _StatCell(
                label: 'GOAL DAY',
                value: '$dayOfGoal of $totalDays',
              ),
            ],
          ),
          const SizedBox(height: 12),
          _GoalDaysBanner(
            isCompleted: isCompleted,
            daysColor: daysColor,
            displayDays: displayDays,
            dateRange: dateRange,
          ),
        ],
      ),
    );
  }

  IconData _goalIcon(String goalType) {
    switch (goalType.toLowerCase()) {
      case 'lose weight':
        return CupertinoIcons.arrow_down_right;
      case 'gain muscle':
        return Icons.fitness_center;
      case 'maintain weight':
        return Icons.balance;
      default:
        return CupertinoIcons.flag;
    }
  }
}

/// Stat cell inside the goal card: tiny uppercase label + value, centered.
class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;

  const _StatCell({required this.label, required this.value, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: ClayTokens.clayDarkTextTertiary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: accent
                  ? ClayTokens.clayPrimaryLight
                  : ClayTokens.clayDarkTextPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Days-left banner: calendar icon + big number, tinted by urgency tier
/// (completed green / overdue & ≤3d red / ≤7d amber / else green) — the
/// same tiers the member's own goal card uses.
class _GoalDaysBanner extends StatelessWidget {
  final bool isCompleted;
  final Color daysColor;
  final int displayDays;
  final String dateRange;

  const _GoalDaysBanner({
    required this.isCompleted,
    required this.daysColor,
    required this.displayDays,
    required this.dateRange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: daysColor.withAlpha(22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: daysColor.withAlpha(70)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: daysColor.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(
              CupertinoIcons.calendar,
              size: 16,
              color: daysColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (!isCompleted) ...[
                      Text(
                        '$displayDays',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: daysColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          displayDays == 1 ? 'day left' : 'days left',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: daysColor,
                          ),
                        ),
                      ),
                    ] else
                      Text(
                        'GOAL COMPLETED',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: daysColor,
                          letterSpacing: 0.3,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  dateRange,
                  style: TextStyle(
                    fontSize: 11,
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

/// Empty state when the member has no running goal.
class _NoGoalCard extends StatelessWidget {
  const _NoGoalCard();

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimaryLight.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              CupertinoIcons.flag,
              size: 18,
              color: ClayTokens.clayPrimaryLight,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No active goal yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Goal progress appears here once a goal is running.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ClayTokens.clayDarkTextTertiary,
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

/// This Week: completed workout sessions per weekday — reads the SAME
/// provider (and therefore the same workout_logs math) as the full Member
/// Progress page, so both screens always show identical numbers.
class _WeekSessionSection extends ConsumerWidget {
  final String id;
  const _WeekSessionSection({required this.id});

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(memberProgressDataProvider(id));
    return progressAsync.when(
      data: (data) {
        final weekCounts = data['weekCounts'] as List<int>;
        final maxWeek = data['maxWeek'] as int;
        final total = weekCounts.fold<int>(0, (a, b) => a + b);
        final today = DateTime.now().weekday - 1;

        return GlassPanel(
          padding: const EdgeInsets.all(14),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'This Week',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: ClayTokens.clayPrimary.withAlpha(60),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$total session${total == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Completed workout sessions, Mon–Sun',
                style: TextStyle(
                  fontSize: 9.5,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 68,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final count = weekCounts[i];
                    final pct = maxWeek > 0 ? (count / maxWeek) : 0.0;
                    final barHeight = (pct * 44).clamp(3.0, 44.0);
                    final isFuture = i > today;
                    final isToday = i == today;
                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (count > 0)
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: isToday
                                    ? ClayTokens.clayPrimaryLight
                                    : ClayTokens.clayDarkTextSecondary,
                              ),
                            ),
                          const SizedBox(height: 3),
                          Container(
                            height: barHeight,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(4),
                              ),
                              color: isFuture
                                  ? ClayTokens.clayDarkTextTertiary
                                      .withAlpha(50)
                                  : ClayTokens.clayPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _labels[i],
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isToday
                                  ? ClayTokens.clayPrimaryLight
                                  : ClayTokens.clayDarkTextTertiary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SkeletonCard(height: 130),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Recent check-ins: the member's latest QR attendance rows (newest first),
/// each with a relative day pill (Today / Yesterday / 3d / 2 wk).
class _CheckinsSection extends StatelessWidget {
  final List<Map<String, dynamic>> checkins; // newest-first
  const _CheckinsSection({required this.checkins});

  String _relativePill(DateTime t) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '$diff d';
    if (diff < 30) return '${(diff / 7).floor()} wk';
    return '${(diff / 30).floor()} mo';
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Check-ins',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          if (checkins.isEmpty)
            Text(
              'No check-ins yet',
              style: TextStyle(
                fontSize: 12,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            )
          else
            ...checkins.take(8).toList().asMap().entries.map((entry) {
              final i = entry.key;
              final row = entry.value;
              final raw = DateTime.tryParse(row['check_in_time'] as String? ?? '');
              if (raw == null) return const SizedBox.shrink();
              final local = raw.toLocal();
              final pill = _relativePill(local);
              final pillColor = pill == 'Today'
                  ? const Color(0xFF30D158)
                  : ClayTokens.clayDarkTextTertiary;
              return Column(
                children: [
                  if (i > 0)
                    Container(
                      height: 1,
                      color: Colors.white.withAlpha(8),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: ClayTokens.clayPrimaryLight.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            CupertinoIcons.clock,
                            size: 14,
                            color: ClayTokens.clayPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, MMM d · h:mm a').format(local),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pillColor.withAlpha(25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            pill,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: pillColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

/// Weight card: latest measurement, delta vs the previous one (up amber,
/// down accent), and the last five measurements as a mini history.
class _WeightSection extends StatelessWidget {
  final List<Map<String, dynamic>> measurements; // newest-first
  const _WeightSection({required this.measurements});

  @override
  Widget build(BuildContext context) {
    final latest = measurements.isEmpty ? null : measurements.first;
    final prev = measurements.length > 1 ? measurements[1] : null;
    final latestWeight = (latest?['weight_kg'] as num?)?.toDouble();
    final prevWeight = (prev?['weight_kg'] as num?)?.toDouble();
    final delta = (latestWeight != null && prevWeight != null)
        ? latestWeight - prevWeight
        : null;

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weight',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (latestWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${latestWeight.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (latestWeight == null)
            Text(
              'No measurements yet',
              style: TextStyle(
                fontSize: 12,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  latestWeight.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.clayDarkTextSecondary,
                    ),
                  ),
                ),
                if (delta != null && delta.abs() >= 0.05) ...[
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delta > 0
                              ? CupertinoIcons.arrow_up_right
                              : CupertinoIcons.arrow_down_right,
                          size: 13,
                          color: delta > 0
                              ? ClayTokens.clayWarning
                              : ClayTokens.clayAccent,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg vs last',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: delta > 0
                                ? ClayTokens.clayWarning
                                : ClayTokens.clayAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: Colors.white.withAlpha(8)),
            ...measurements.take(5).toList().asMap().entries.map((entry) {
              final row = entry.value;
              final weight = (row['weight_kg'] as num?)?.toDouble();
              final raw =
                  DateTime.tryParse(row['measured_at'] as String? ?? '');
              if (weight == null || raw == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat('EEE, MMM d').format(raw.toLocal()),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ClayTokens.clayDarkTextSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${weight.toStringAsFixed(1)} kg',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// Bridge to the full Member Progress page (month/growth charts + calendar
/// flip sheet), so nothing reachable before is lost behind the new screen.
class _FullProgressLink extends StatelessWidget {
  final String id;
  const _FullProgressLink({required this.id});

  @override
  Widget build(BuildContext context) {
    return PressableCard(
      onTap: () => context.push('/trainer/members/$id'),
      padding: const EdgeInsets.all(14),
      color: ClayTokens.clayPrimaryLight.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withAlpha(18)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(60),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              CupertinoIcons.chart_bar_fill,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'View full progress',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Charts, calendar & growth',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 18,
            color: ClayTokens.clayDarkTextTertiary,
          ),
        ],
      ),
    );
  }
}
