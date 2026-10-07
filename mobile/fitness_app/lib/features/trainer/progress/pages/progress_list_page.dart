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
import '../../../shared/services/prediction_service.dart';

/// Assigned members with their progress overview - latest weight + trend,
/// running goal, last check-in, and retention risk - fetched in FOUR parallel
/// queries (profiles + measurements + goals + attendance) plus the per-member
/// retention forecast. Keep-alive (not autoDispose): the indexed-stack shell
/// keeps this page alive, so revisits render cached rows instantly while the
/// router listener below refetches in the background.
final assignedMembersWithStatsProvider =
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
        // Newest-first: the first two rows per member give latest weight + delta.
        client
            .from('body_measurements')
            .select('member_id, weight_kg')
            .inFilter('member_id', memberIds)
            .order('measured_at', ascending: false),
        // Members create goals as 'in_progress' while seeds use 'active'; a
        // running goal is either.
        client
            .from('goals')
            .select('member_id, title, target_value, current_value')
            .inFilter('member_id', memberIds)
            .inFilter('status', ['active', 'in_progress'])
            .order('created_at', ascending: false),
        client
            .from('attendance')
            .select('member_id, check_in_time')
            .inFilter('member_id', memberIds)
            .gte('check_in_time', ninetyDaysAgo.toIso8601String()),
      ]);

      final profileList = (results[0] as List).cast<Map<String, dynamic>>();

      // Latest two measurements per member (rows arrive newest-first).
      final measByMember = <String, List<Map<String, dynamic>>>{};
      for (final m in (results[1] as List).cast<Map<String, dynamic>>()) {
        final mid = m['member_id'] as String?;
        if (mid == null) continue;
        final bucket = measByMember.putIfAbsent(mid, () => []);
        if (bucket.length < 2) bucket.add(m);
      }

      // Newest running goal per member.
      final goalByMember = <String, Map<String, dynamic>>{};
      for (final g in (results[2] as List).cast<Map<String, dynamic>>()) {
        final mid = g['member_id'] as String?;
        if (mid != null) goalByMember.putIfAbsent(mid, () => g);
      }

      final lastCheckIn = <String, DateTime>{};
      for (final a in (results[3] as List).cast<Map<String, dynamic>>()) {
        final mid = a['member_id'] as String?;
        final t = DateTime.tryParse(a['check_in_time'] as String? ?? '');
        if (mid == null || t == null) continue;
        final prev = lastCheckIn[mid];
        if (prev == null || t.isAfter(prev)) lastCheckIn[mid] = t;
      }

      // Retention risk (AI service, local scikit-learn) for each assigned
      // member. Requests capped at 30; a member without enough data or a
      // failed call simply drops the risk badge instead of failing the page.
      final predictionService = PredictionService();
      final riskByMember = <String, String>{};
      try {
        final forecasts = await Future.wait(
          memberIds.take(30).map((id) => predictionService.getForecast(id)),
        );
        for (var i = 0; i < forecasts.length; i++) {
          final risk = forecasts[i].retention;
          if (risk == null) continue;
          riskByMember[memberIds[i]] = risk.riskLabel;
        }
      } catch (e) {
        debugPrint('Retention risk fetch failed: $e');
      }

      final rows = profileList.map((p) {
        final mid = p['id'] as String;
        final meas = measByMember[mid] ?? const <Map<String, dynamic>>[];
        final latest = meas.isNotEmpty ? meas.first : null;
        final prevM = meas.length > 1 ? meas[1] : null;
        final latestWeight = (latest?['weight_kg'] as num?)?.toDouble();
        final prevWeight = (prevM?['weight_kg'] as num?)?.toDouble();
        final goal = goalByMember[mid];
        final target = (goal?['target_value'] as num?)?.toDouble();
        final current = (goal?['current_value'] as num?)?.toDouble();
        return <String, dynamic>{
          'id': mid,
          'full_name': p['full_name'] as String? ?? 'Unknown',
          'avatar_url': p['avatar_url'] as String?,
          'code': p['code'] as String?,
          'weight': latestWeight,
          'weightDelta': (latestWeight != null && prevWeight != null)
              ? latestWeight - prevWeight
              : null,
          'goal_title': goal?['title'] as String?,
          'goal_pct': (target != null && target > 0 && current != null)
              ? (current / target).clamp(0.0, 1.0)
              : null,
          'last_checkin': lastCheckIn[mid],
          'risk_label': riskByMember[mid],
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
      ref.invalidate(assignedMembersWithStatsProvider);
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
    final membersAsync = ref.watch(assignedMembersWithStatsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Members'),
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
                          label: 'View $name progress',
                          child: _MemberProgressCard(data: m),
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

/// Glass progress card for one assigned member (Profile Features-card style):
/// avatar, latest weight + trend, goal progress, and last check-in. Taps
/// through to the member's full progress page.
class _MemberProgressCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _MemberProgressCard({required this.data});

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
    final weight = (data['weight'] as num?)?.toDouble();
    final delta = (data['weightDelta'] as num?)?.toDouble();
    final goalTitle = data['goal_title'] as String?;
    final goalPct = (data['goal_pct'] as num?)?.toDouble();
    final lastCheckin = data['last_checkin'] as DateTime?;
    final riskLabel = data['risk_label'] as String?;

    final riskColor = riskLabel == 'high'
        ? const Color(0xFFFF453A)
        : riskLabel == 'medium'
        ? const Color(0xFFFF9500)
        : const Color(0xFF30D158);

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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (riskLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: riskColor.withAlpha(25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          riskLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: riskColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (weight != null)
                  Row(
                    children: [
                      Text(
                        '${weight.toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: ClayTokens.clayPrimaryLight,
                        ),
                      ),
                      if (delta != null && delta.abs() >= 0.05) ...[
                        const SizedBox(width: 5),
                        Icon(
                          delta > 0
                              ? CupertinoIcons.arrow_up_right
                              : CupertinoIcons.arrow_down_right,
                          size: 12,
                          color: delta > 0
                              ? ClayTokens.clayWarning
                              : ClayTokens.clayAccent,
                        ),
                        Text(
                          '${delta.toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: delta > 0
                                ? ClayTokens.clayWarning
                                : ClayTokens.clayAccent,
                          ),
                        ),
                      ],
                    ],
                  )
                else
                  Text(
                    'No measurements yet',
                    style: TextStyle(
                      fontSize: 11,
                      color: ClayTokens.clayDarkTextTertiary,
                    ),
                  ),
                if (goalTitle != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: goalPct ?? 0,
                            minHeight: 5,
                            backgroundColor: Colors.white.withAlpha(25),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              ClayTokens.clayPrimaryLight,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        goalPct != null
                            ? '${(goalPct * 100).round()}%'
                            : goalTitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: ClayTokens.clayDarkTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 5),
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
