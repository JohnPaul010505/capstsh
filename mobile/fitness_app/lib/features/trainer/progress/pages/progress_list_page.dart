import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/utils/goal_progress.dart';

/// Assigned members for the trainer Members list - deliberately SLIM: name,
/// avatar, member code and last check-in only. Weight, goal progress,
/// retention risk and check-in history all live on the Member Progress
/// screen (/trainer/members/:id) this row opens. Two fast parallel DB
/// queries (profiles + attendance); no per-row AI forecast ever touches the
/// list path. Keep-alive (not autoDispose): the indexed-stack shell keeps
/// this page alive, so revisits render cached rows instantly while the
/// router listener below refetches in the background.
final assignedMembersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
      final client = SupabaseClientService().client;
      final userId = client.auth.currentUser!.id;

      final assignments = await client
          .from('trainer_assignments')
          .select('member_id')
          .eq('trainer_id', userId)
          .eq('status', 'active');

      final memberIds = (assignments as List)
          .map((a) => a['member_id'] as String)
          .toList();
      if (memberIds.isEmpty) return [];

      final ninetyDaysAgo = DateTime.now().subtract(const Duration(days: 90));

      final results = await Future.wait([
        client
            .from('profiles')
            .select('id, full_name, avatar_url, code')
            .inFilter('id', memberIds),
        client
            .from('attendance')
            .select('member_id, check_in_time')
            .inFilter('member_id', memberIds)
            .gte('check_in_time', ninetyDaysAgo.toIso8601String()),
        // Latest two measurements per member (newest first) → current weight +
        // the delta vs the previous reading for the "↗ 2.0kg" badge.
        client
            .from('body_measurements')
            .select('member_id, weight_kg, measured_at')
            .inFilter('member_id', memberIds)
            .not('weight_kg', 'is', null)
            .order('measured_at', ascending: false),
        // Running goals (newest first) → goal_type + target for the journey bar.
        client
            .from('goals')
            .select(
              'member_id, title, goal_type, target_value, current_value, status',
            )
            .inFilter('member_id', memberIds)
            .inFilter('status', ['active', 'in_progress'])
            .order('created_at', ascending: false),
      ]);

      final profileList = (results[0] as List).cast<Map<String, dynamic>>();

      // Most recent check-in per member.
      final lastCheckIn = <String, DateTime>{};
      for (final a in (results[1] as List).cast<Map<String, dynamic>>()) {
        final mid = a['member_id'] as String?;
        final t = DateTime.tryParse(a['check_in_time'] as String? ?? '');
        if (mid == null || t == null) continue;
        final prev = lastCheckIn[mid];
        if (prev == null || t.isAfter(prev)) lastCheckIn[mid] = t;
      }

      // Latest + previous weight per member (rows are newest-first, so the
      // first sighting is the current weight and the second is the prior one).
      final latestWeight = <String, double>{};
      final prevWeight = <String, double>{};
      for (final m in (results[2] as List).cast<Map<String, dynamic>>()) {
        final mid = m['member_id'] as String?;
        final w = (m['weight_kg'] as num?)?.toDouble();
        if (mid == null || w == null) continue;
        if (latestWeight.containsKey(mid)) {
          prevWeight.putIfAbsent(mid, () => w);
        } else {
          latestWeight[mid] = w;
        }
      }

      // Newest running goal per member.
      final goalByMember = <String, Map<String, dynamic>>{};
      for (final g in (results[3] as List).cast<Map<String, dynamic>>()) {
        final mid = g['member_id'] as String?;
        if (mid == null) continue;
        goalByMember.putIfAbsent(mid, () => g);
      }

      final rows = profileList.map((p) {
        final mid = p['id'] as String;
        final goal = goalByMember[mid];
        final goalType = (goal?['goal_type'] as String?) ?? '';
        final live = latestWeight[mid];
        final goalPct = goal == null
            ? null
            : computeGoalProgress(
                baseline: (goal['current_value'] as num?)?.toDouble(),
                target: (goal['target_value'] as num?)?.toDouble(),
                live: live,
                goalType: goalType,
              ).pct;
        return <String, dynamic>{
          'id': mid,
          'full_name': p['full_name'] as String? ?? 'Unknown',
          'avatar_url': p['avatar_url'] as String?,
          'code': p['code'] as String?,
          'last_checkin': lastCheckIn[mid],
          'weight': live,
          'weight_delta':
              (live != null && prevWeight[mid] != null && prevWeight[mid] != live)
              ? live - prevWeight[mid]!
              : null,
          'goal_pct': goalPct,
        };
      }).toList();

      // Most recent activity first; members who never checked in sort last.
      rows.sort((a, b) {
        final la = a['last_checkin'] as DateTime?;
        final lb = b['last_checkin'] as DateTime?;
        if (la == null && lb == null) return 0;
        if (la == null) return 1;
        if (lb == null) return -1;
        return lb.compareTo(la);
      });
      return rows;
    });

class ProgressListPage extends ConsumerStatefulWidget {
  const ProgressListPage({super.key});

  @override
  ConsumerState<ProgressListPage> createState() => _ProgressListPageState();
}

class _ProgressListPageState extends ConsumerState<ProgressListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  // Refresh-on-return: the indexed-stack shell keeps this page alive, so a
  // router listener refetches while cached rows render instantly.
  GoRouter? _router;
  bool _wasMembers = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router ??= GoRouter.of(context);
    _router!.routerDelegate.addListener(_onRouteChanged);
  }

  void _onRouteChanged() {
    final isMembers =
        _router!.routerDelegate.currentConfiguration.uri.path ==
        '/trainer/members';
    if (isMembers && !_wasMembers && mounted) {
      ref.invalidate(assignedMembersProvider);
    }
    _wasMembers = isMembers;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(assignedMembersProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Member Progress'),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                child: GlassPanel(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                  style: ClayTokens.bodyLarge.copyWith(
                    color: ClayTokens.clayDarkTextPrimary,
                    fontSize: 14,
                  ),
                  cursorColor: ClayTokens.clayPrimary,
                  decoration: InputDecoration(
                    hintText: 'Search members',
                    hintStyle: ClayTokens.bodySmall.copyWith(
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: ClayTokens.clayDarkTextTertiary,
                      size: 18,
                    ),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: ClayTokens.clayDarkTextTertiary,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.transparent,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Colors.white.withAlpha(24),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: ClayTokens.clayPrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                ),
              ),
              Expanded(
                child: membersAsync.when(
                  // Cached rows stay on screen during background refetches
                  // (the router listener invalidates on every tab return).
                  skipLoadingOnRefresh: true,
                  skipLoadingOnReload: true,
                  data: (members) {
                    if (members.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              CupertinoIcons.person_2,
                              color: ClayTokens.clayDarkTextTertiary,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No assigned members yet',
                              style: ClayTokens.bodySmall.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                                color: ClayTokens.clayDarkTextTertiary,
                                letterSpacing: -0.08,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    // Client-side search on name + member code (e.g. M002).
                    final q = _query;
                    final filtered = q.isEmpty
                        ? members
                        : members.where((m) {
                            final name = (m['full_name'] as String? ?? '')
                                .toLowerCase();
                            final code = (m['code'] as String? ?? '')
                                .toLowerCase();
                            return name.contains(q) || code.contains(q);
                          }).toList();
                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          'No members match "${_searchController.text.trim()}"',
                          style: ClayTokens.bodySmall.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: ClayTokens.clayDarkTextTertiary,
                            letterSpacing: -0.08,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      key: ValueKey('members-$_query'),
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final name = m['full_name'] as String? ?? 'Unknown';
                        return Semantics(
                          label: 'View $name insights',
                          child: _MemberRow(data: m),
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
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: ClayTokens.labelMedium.copyWith(
                        fontWeight: FontWeight.w400,
                        color: ClayTokens.clayDarkTextTertiary,
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
}

/// Slim glass row for one assigned member: avatar, name and last check-in.
/// Everything else (goal progress, retention risk, measurements, check-in
/// history) lives on the Member Insight screen this row opens.
class _MemberRow extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MemberRow({required this.data});

  String _lastCheckinLabel(DateTime? t) {
    if (t == null) return 'No check-ins yet';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(t.year, t.month, t.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Last check-in today';
    if (diff == 1) return 'Last check-in yesterday';
    if (diff < 7) return 'Last check-in $diff days ago';
    if (diff < 30) return 'Last check-in ${(diff / 7).floor()} wk ago';
    return 'Last check-in ${(diff / 30).floor()} mo ago';
  }

  @override
  Widget build(BuildContext context) {
    final name = data['full_name'] as String? ?? 'Unknown';
    final initials = name
        .split(' ')
        .map((n) => n.isNotEmpty ? n[0] : '')
        .take(2)
        .join();
    final lastCheckin = data['last_checkin'] as DateTime?;
    final weight = (data['weight'] as num?)?.toDouble();
    final delta = (data['weight_delta'] as num?)?.toDouble();

    return PressableCard(
      onTap: () => context.push('/trainer/members/${data['id']}'),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      color: ClayTokens.clayPrimaryLight.withAlpha(25),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withAlpha(18)),
      child: Row(
        children: [
          ClayAvatar(
            imageUrl: data['avatar_url'] as String?,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                if (weight != null)
                  _WeightLine(weight: weight, delta: delta)
                else
                  Text(
                    'No measurements yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                  ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.clock,
                      size: 11,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _lastCheckinLabel(lastCheckin),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "62.0 kg ↗ 2.0kg" — weight plus the delta vs the previous reading. The
/// journey bar and "20% of target" label were removed per trainer feedback;
/// the progress list stays a compact at-a-glance row.
class _WeightLine extends StatelessWidget {
  final double weight;
  final double? delta;

  const _WeightLine({required this.weight, this.delta});

  @override
  Widget build(BuildContext context) {
    final hasDelta = delta != null && delta != 0;
    final rising = (delta ?? 0) > 0;
    final deltaColor = rising
        ? const Color(0xFF30D158)
        : const Color(0xFFFF9F0A);

    return Row(
      children: [
        Text(
          '${weight.toStringAsFixed(1)} kg',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        if (hasDelta) ...[
          const SizedBox(width: 5),
          Icon(
            rising ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 12,
            color: deltaColor,
          ),
          const SizedBox(width: 2),
          Text(
            '${delta!.abs().toStringAsFixed(1)}kg',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: deltaColor,
            ),
          ),
        ],
      ],
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
