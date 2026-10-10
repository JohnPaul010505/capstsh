import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/utils/goal_progress.dart';

/// Value-typed date window for the Member Insight overview. The trainer picks
/// a preset (Today / Last 7 / This month / All) or a custom start+end; the
/// provider refetches only when the bounds actually move.
class InsightRange {
  final DateTime start;
  final DateTime end;
  const InsightRange(this.start, this.end);

  @override
  bool operator ==(Object other) =>
      other is InsightRange &&
      other.start.isAtSameMomentAs(start) &&
      other.end.isAtSameMomentAs(end);

  @override
  int get hashCode =>
      Object.hash(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
}

/// One row in the "Members Needing Attention" list.
class AttentionMember {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? code;
  final String reason;
  final int daysInactive;

  const AttentionMember({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.code,
    required this.reason,
    required this.daysInactive,
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

/// Per-goal-type progress bucket for the Goals Progress Overview.
class GoalBucket {
  final String goalType;
  final int count;
  final double avgPct;

  const GoalBucket({
    required this.goalType,
    required this.count,
    required this.avgPct,
  });
}

/// Everything the Member Insight overview screen renders, computed once per
/// [InsightRange] so the four stat cards, the goals breakdown and the
/// attention list all agree on the same window.
class MemberInsightOverview {
  final int totalMembers;
  final int activeMembers;
  final int inactiveMembers;
  final int highRiskMembers;
  final List<GoalBucket> goalBuckets;
  final List<AttentionMember> attention;

  const MemberInsightOverview({
    required this.totalMembers,
    required this.activeMembers,
    required this.inactiveMembers,
    required this.highRiskMembers,
    required this.goalBuckets,
    required this.attention,
  });
}

/// Builds the Member Insight overview for the signed-in trainer's assigned
/// roster inside [range]. Two things drive the numbers:
/// * **active / inactive / high risk** come from attendance (a member is
///   active if they checked in during the window; high risk = no check-in in
///   the window for 7+ days or never). No per-member AI call touches this path
///   — the roster can be large and the forecast service sits behind a tunnel.
/// * **Goals Progress** groups each member's running goal by `goal_type` and
///   averages the shared [computeGoalProgress] journey percentage, so trainer
///   and member never disagree on progress.
final memberInsightOverviewProvider = FutureProvider.autoDispose
    .family<MemberInsightOverview, InsightRange>((ref, range) async {
      final client = SupabaseClientService().client;
      final trainerId = client.auth.currentUser!.id;

      // Assigned members (roster).
      final assignments = await client
          .from('trainer_assignments')
          .select('member_id')
          .eq('trainer_id', trainerId)
          .eq('status', 'active');
      final memberIds = (assignments as List)
          .map((a) => a['member_id'] as String)
          .toSet()
          .toList();
      if (memberIds.isEmpty) {
        return const MemberInsightOverview(
          totalMembers: 0,
          activeMembers: 0,
          inactiveMembers: 0,
          highRiskMembers: 0,
          goalBuckets: [],
          attention: [],
        );
      }

      final results = await Future.wait([
        client
            .from('profiles')
            .select('id, full_name, avatar_url, code')
            .inFilter('id', memberIds),
        // Check-ins inside the window → active count.
        client
            .from('attendance')
            .select('member_id, check_in_time')
            .inFilter('member_id', memberIds)
            .gte('check_in_time', range.start.toUtc().toIso8601String())
            .lte('check_in_time', range.end.toUtc().toIso8601String()),
        // Full recent history (newest first) → days-inactive per member.
        client
            .from('attendance')
            .select('member_id, check_in_time')
            .inFilter('member_id', memberIds)
            .order('check_in_time', ascending: false),
        // Running goals for every assigned member, newest first.
        client
            .from('goals')
            .select(
              'member_id, title, goal_type, target_value, current_value, status',
            )
            .inFilter('member_id', memberIds)
            .inFilter('status', ['active', 'in_progress'])
            .order('created_at', ascending: false),
        // Latest weight per member feeds the journey math.
        client
            .from('body_measurements')
            .select('member_id, weight_kg, measured_at')
            .inFilter('member_id', memberIds)
            .order('measured_at', ascending: false),
      ]);

      final profiles = (results[0] as List).cast<Map<String, dynamic>>();
      final windowCheckins = (results[1] as List).cast<Map<String, dynamic>>();
      final allCheckins = (results[2] as List).cast<Map<String, dynamic>>();
      final goals = (results[3] as List).cast<Map<String, dynamic>>();
      final measurements = (results[4] as List).cast<Map<String, dynamic>>();

      final profileById = {for (final p in profiles) p['id'] as String: p};

      // Members who checked in at least once inside the window.
      final activeInWindow = <String>{};
      for (final c in windowCheckins) {
        final mid = c['member_id'] as String?;
        if (mid != null) activeInWindow.add(mid);
      }

      // Most recent check-in per member (across all time) → days inactive.
      final lastCheckIn = <String, DateTime>{};
      for (final c in allCheckins) {
        final mid = c['member_id'] as String?;
        final t = DateTime.tryParse(c['check_in_time'] as String? ?? '');
        if (mid == null || t == null) continue;
        final prev = lastCheckIn[mid];
        if (prev == null || t.isAfter(prev)) lastCheckIn[mid] = t;
      }

      // Latest weight per member for journey math.
      final liveWeight = <String, double>{};
      for (final m in measurements) {
        final mid = m['member_id'] as String?;
        final w = (m['weight_kg'] as num?)?.toDouble();
        if (mid == null || w == null) continue;
        liveWeight.putIfAbsent(mid, () => w);
      }

      // Newest running goal per member.
      final goalByMember = <String, Map<String, dynamic>>{};
      for (final g in goals) {
        final mid = g['member_id'] as String?;
        if (mid == null) continue;
        goalByMember.putIfAbsent(mid, () => g);
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);


      // --- Goals Progress Overview grouped by goal_type -----------------------
      final bucketSums = <String, List<double>>{};
      const knownTypes = ['Lose Weight', 'Gain Muscle', 'Maintain Weight'];
      for (final t in knownTypes) {
        bucketSums[t] = <double>[];
      }
      for (final g in goalByMember.values) {
        final type = (g['goal_type'] as String?)?.trim();
        if (type == null || type.isEmpty) continue;
        final mid = g['member_id'] as String;
        final pct = computeGoalProgress(
          baseline: (g['current_value'] as num?)?.toDouble(),
          target: (g['target_value'] as num?)?.toDouble(),
          live: liveWeight[mid],
          goalType: type,
        ).pct;
        (bucketSums[type] ??= <double>[]).add(pct);
      }
      // Always surface the three known goal types in a fixed order so the
      // trainer sees Lose Weight / Gain Muscle / Maintain Weight even when a
      // type currently has no running goal (0% / 0 members), instead of the
      // list collapsing to whichever single type happens to be populated.
      final goalBuckets = <GoalBucket>[];
      for (final type in knownTypes) {
        final values = bucketSums[type] ?? const <double>[];
        final avg = values.isEmpty
            ? 0.0
            : values.reduce((a, b) => a + b) / values.length;
        goalBuckets.add(
          GoalBucket(goalType: type, count: values.length, avgPct: avg),
        );
      }
      // Any non-standard goal_type that actually appears still gets a row,
      // appended after the known three.
      for (final entry in bucketSums.entries) {
        if (knownTypes.contains(entry.key)) continue;
        final values = entry.value;
        if (values.isEmpty) continue;
        final avg = values.reduce((a, b) => a + b) / values.length;
        goalBuckets.add(
          GoalBucket(goalType: entry.key, count: values.length, avgPct: avg),
        );
      }

      // --- Stat cards + attention list ----------------------------------------
      int active = 0;
      int highRisk = 0;
      final attention = <AttentionMember>[];
      for (final mid in memberIds) {
        final profile = profileById[mid];
        final name = (profile?['full_name'] as String?)?.trim();
        final displayName = (name == null || name.isEmpty) ? 'Member' : name;
        final avatar = profile?['avatar_url'] as String?;
        final code = profile?['code'] as String?;

        final checkedInWindow = activeInWindow.contains(mid);
        if (checkedInWindow) active++;

        final last = lastCheckIn[mid];
        final daysInactive = last == null
            ? 999
            : today
                  .difference(DateTime(last.year, last.month, last.day))
                  .inDays;

        final isHighRisk = !checkedInWindow && daysInactive >= 7;
        if (isHighRisk) highRisk++;

        if (!checkedInWindow) {
          attention.add(
            AttentionMember(
              id: mid,
              name: displayName,
              avatarUrl: avatar,
              code: code,
              reason: last == null
                  ? 'No check-ins yet'
                  : 'No check-in for $daysInactive days',
              daysInactive: daysInactive,
            ),
          );
        }
      }

      // Most-inactive first so the trainer sees the riskiest members on top.
      attention.sort((a, b) => b.daysInactive.compareTo(a.daysInactive));

      return MemberInsightOverview(
        totalMembers: memberIds.length,
        activeMembers: active,
        inactiveMembers: memberIds.length - active,
        highRiskMembers: highRisk,
        goalBuckets: goalBuckets,
        attention: attention,
      );
    });

