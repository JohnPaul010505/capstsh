import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/skeleton.dart';
import '../providers/member_insight_overview_provider.dart';

/// A date-filtered roster overview. Four stat cards (Total / Active / Inactive
/// / High risk) summarise the selected window; a Goals Progress Overview
/// breaks the running goals down by `goal_type`; and a paginated "Members
/// Needing Attention" list surfaces the members who have not checked in.
/// Tapping any attention row opens that member's Member Progress screen.
///
/// This is the embeddable body the trainer dashboard's 4th burger-menu screen
/// renders directly (it owns its own range + page state, so it needs no
/// Scaffold or nav bar). [MemberInsightOverviewPage] wraps it full-screen for
/// direct navigation.
class MemberInsightOverviewView extends ConsumerStatefulWidget {
  const MemberInsightOverviewView({super.key});

  @override
  ConsumerState<MemberInsightOverviewView> createState() =>
      _MemberInsightOverviewViewState();
}

class _MemberInsightOverviewViewState
    extends ConsumerState<MemberInsightOverviewView> {
  String _preset = 'month';
  late DateTime _start;
  late DateTime _end;

  // Attention list paging (client-side over the provider's sorted list).
  static const _pageSize = 5;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    DateTime start;
    switch (preset) {
      case 'today':
        start = today;
        break;
      case 'all':
        start = DateTime(2023, 1, 1);
        break;
      case 'last7':
      default:
        start = today.subtract(const Duration(days: 6));
        break;
    }
    setState(() {
      _preset = preset;
      _start = start;
      _end = end;
      _page = 0;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: ClayTokens.clayPrimary,
            onPrimary: Colors.white,
            surface: ClayTokens.clayDarkSurfaceElevated,
            onSurface: ClayTokens.clayDarkTextPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF14142A).withAlpha(175),
                    const Color(0xFF221A4A).withAlpha(145),
                    const Color(0xFF14142A).withAlpha(185),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(38)),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    final dayEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    setState(() {
      _preset = 'custom';
      if (isStart) {
        _start = day;
        if (_end.isBefore(_start)) _end = dayEnd;
      } else {
        _end = dayEnd;
        if (_start.isAfter(_end)) _start = day;
      }
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final range = InsightRange(_start, _end);
    final dataAsync = ref.watch(memberInsightOverviewProvider(range));

    return dataAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SizedBox(height: 8),
            SkeletonCard(height: 96),
            SkeletonCard(height: 120),
            SkeletonCard(height: 160),
            SkeletonCard(height: 200),
          ],
        ),
      ),
      error: (e, _) => _ErrorState(message: '$e'),
      data: _buildContent,
    );
  }

  Widget _buildContent(MemberInsightOverview data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      physics: const ClampingScrollPhysics(),
      children: [
        const _InsightHeader(),
        const SizedBox(height: 12),
        _RangeBar(
          preset: _preset,
          start: _start,
          end: _end,
          onPreset: _applyPreset,
          onPickStart: () => _pickDate(isStart: true),
          onPickEnd: () => _pickDate(isStart: false),
        ),
        const SizedBox(height: 12),
        _StatCards(data: data),
        const SizedBox(height: 12),
        _GoalsProgress(buckets: data.goalBuckets),
        const SizedBox(height: 12),
        _AttentionSection(
          members: data.attention,
          page: _page,
          pageSize: _pageSize,
          onPage: (p) => setState(() => _page = p),
        ),
      ],
    );
  }
}

/// Screen title + one-line description, matching the Daily Check-ins header so
/// the Member Insight reads as a titled report rather than a bare card stack.
class _InsightHeader extends StatelessWidget {
  const _InsightHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Member Insight',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
              fontFamily: ClayTypography.headingFamily,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Your roster's activity, goals and at-a-glance risk in the "
            'selected window.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.35,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen wrapper around [MemberInsightOverviewView] for direct
/// navigation (with its own nav bar + glow background).
class MemberInsightOverviewPage extends StatelessWidget {
  const MemberInsightOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _InsightNavBar(),
              Expanded(child: MemberInsightOverviewView()),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Nav bar + error state
// ---------------------------------------------------------------------------

class _InsightNavBar extends StatelessWidget {
  const _InsightNavBar();

  @override
  Widget build(BuildContext context) {
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
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chart_bar_square,
              color: ClayTokens.clayDarkTextTertiary,
              size: 34,
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load the overview',
              style: ClayTokens.bodySmall.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: ClayTokens.bodySmall.copyWith(
                fontSize: 11,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Range bar (start/end + preset chips) — mirrors the dashboard's _RangeBar
// ---------------------------------------------------------------------------

class _RangeBar extends StatelessWidget {
  final String preset;
  final DateTime start;
  final DateTime end;
  final void Function(String preset) onPreset;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;

  const _RangeBar({
    required this.preset,
    required this.start,
    required this.end,
    required this.onPreset,
    required this.onPickStart,
    required this.onPickEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.all(10),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _DateField(label: 'Start date', date: start, onTap: onPickStart),
              const SizedBox(width: 8),
              _DateField(label: 'End date', date: end, onTap: onPickEnd),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PresetChip(
                label: 'Today',
                value: 'today',
                selected: preset == 'today',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'Last 7 days',
                value: 'last7',
                selected: preset == 'last7',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'This month',
                value: 'month',
                selected: preset == 'month',
                onTap: onPreset,
              ),
              _PresetChip(
                label: 'All time',
                value: 'all',
                selected: preset == 'all',
                onTap: onPreset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(14),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withAlpha(30)),
          ),
          child: Row(
            children: [
              Icon(
                CupertinoIcons.calendar,
                size: 13,
                color: ClayTokens.clayDarkTextTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      DateFormat('MMM d, y').format(date),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextPrimary,
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
}

class _PresetChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final void Function(String preset) onTap;

  const _PresetChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? ClayTokens.clayPrimary
              : Colors.white.withAlpha(14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? ClayTokens.clayPrimary
                : Colors.white.withAlpha(30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : ClayTokens.clayDarkTextSecondary,
          ),
        ),
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Four stat cards: Total / Active / Inactive / High risk
// ---------------------------------------------------------------------------

class _StatCards extends StatelessWidget {
  final MemberInsightOverview data;
  const _StatCards({required this.data});

  @override
  Widget build(BuildContext context) {
    // 2x2 grid (matches Daily Check-ins) instead of four cramped cards.
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total',
                value: '${data.totalMembers}',
                icon: Icons.groups_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Active',
                value: '${data.activeMembers}',
                icon: Icons.check_circle_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Inactive',
                value: '${data.inactiveMembers}',
                icon: Icons.bedtime_rounded,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'High risk',
                value: '${data.highRiskMembers}',
                icon: Icons.warning_amber_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: Colors.white, size: 17),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Goals Progress Overview — running goals grouped by goal_type
// ---------------------------------------------------------------------------

const _goalTypeIcon = <String, IconData>{
  'Lose Weight': CupertinoIcons.arrow_down_circle,
  'Gain Muscle': CupertinoIcons.arrow_up_circle,
  'Maintain Weight': CupertinoIcons.equal_circle,
};

const _goalTypeColor = <String, Color>{
  'Lose Weight': Color(0xFF0A84FF),
  'Gain Muscle': Color(0xFF30D158),
  'Maintain Weight': Color(0xFFFF9500),
};

class _GoalsProgress extends StatelessWidget {
  final List<GoalBucket> buckets;
  const _GoalsProgress({required this.buckets});

  @override
  Widget build(BuildContext context) {
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
                'Goals Progress Overview',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'by goal type',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (buckets.isEmpty)
            _GoalsEmpty()
          else
            ...buckets.map((b) => _GoalBucketRow(bucket: b)),
        ],
      ),
    );
  }
}

class _GoalsEmpty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.flag,
            size: 15,
            color: ClayTokens.clayDarkTextTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            'No running goals in this window',
            style: TextStyle(
              fontSize: 12,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalBucketRow extends StatelessWidget {
  final GoalBucket bucket;
  const _GoalBucketRow({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final color = _goalTypeColor[bucket.goalType] ?? ClayTokens.clayPrimary;
    final icon = _goalTypeIcon[bucket.goalType] ?? CupertinoIcons.flag;
    final pct = bucket.avgPct.clamp(0.0, 100.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  bucket.goalType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${pct.round()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${bucket.count} member${bucket.count == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: ClayTokens.clayDarkTextTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct / 100.0,
              minHeight: 6,
              backgroundColor: Colors.white.withAlpha(20),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------------------
// Members Needing Attention — paginated (pageSize per page) attention list
// ---------------------------------------------------------------------------

class _AttentionSection extends StatelessWidget {
  final List<AttentionMember> members;
  final int page;
  final int pageSize;
  final void Function(int page) onPage;

  const _AttentionSection({
    required this.members,
    required this.page,
    required this.pageSize,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = members.isEmpty ? 1 : (members.length / pageSize).ceil();
    final safePage = page.clamp(0, totalPages - 1);
    final start = safePage * pageSize;
    final end = (start + pageSize).clamp(0, members.length);
    final slice = members.isEmpty
        ? const <AttentionMember>[]
        : members.sublist(start, end);

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
                'Members Needing Attention',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              if (members.isNotEmpty)
                Text(
                  '${start + 1}–$end of ${members.length}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (members.isEmpty)
            const _AttentionEmpty()
          else
            ...slice.map((m) => _AttentionRow(member: m)),
          if (members.length > pageSize) ...[
            const SizedBox(height: 6),
            _AttentionPager(
              page: safePage,
              totalPages: totalPages,
              onPage: onPage,
            ),
          ],
        ],
      ),
    );
  }
}

class _AttentionEmpty extends StatelessWidget {
  const _AttentionEmpty();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.checkmark_seal,
            size: 16,
            color: const Color(0xFF30D158),
          ),
          const SizedBox(width: 8),
          Text(
            'Everyone checked in — nothing needs attention',
            style: TextStyle(
              fontSize: 12,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}


class _AttentionRow extends StatelessWidget {
  final AttentionMember member;
  const _AttentionRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final never = member.daysInactive >= 999;
    // Purple attention chip — matches the app-wide accent (was red/amber).
    final chipColor = ClayTokens.clayPrimary;

    return PressableCard(
      onTap: () => context.push('/trainer/members/${member.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      color: Colors.white.withAlpha(12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withAlpha(16)),
      child: Row(
        children: [
          ClayAvatar(
            imageUrl: member.avatarUrl,
            initials: member.initials,
            size: ClayAvatarSize.sm,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  member.reason,
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
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: chipColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              never ? 'No data' : '${member.daysInactive}d',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttentionPager extends StatelessWidget {
  final int page;
  final int totalPages;
  final void Function(int page) onPage;

  const _AttentionPager({
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _PagerButton(
          icon: CupertinoIcons.chevron_left,
          enabled: page > 0,
          onTap: () => onPage(page - 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Page ${page + 1} of $totalPages',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ),
        _PagerButton(
          icon: CupertinoIcons.chevron_right,
          enabled: page < totalPages - 1,
          onTap: () => onPage(page + 1),
        ),
      ],
    );
  }
}

class _PagerButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _PagerButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(enabled ? 18 : 8),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withAlpha(enabled ? 30 : 12),
          ),
        ),
        child: Icon(
          icon,
          size: 15,
          color: enabled
              ? ClayTokens.clayDarkTextPrimary
              : ClayTokens.clayDarkTextTertiary,
        ),
      ),
    );
  }
}

