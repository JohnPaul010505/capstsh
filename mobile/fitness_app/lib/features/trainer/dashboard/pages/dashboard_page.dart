import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';

final trainerDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final members = await client
      .from('trainer_assignments')
      .select('member_id')
      .eq('trainer_id', userId)
      .eq('status', 'active');

  final memberIds = (members as List).map((m) => m['member_id'] as String).toList();
  if (memberIds.isEmpty) {
    return {
      'totalMembers': 0, 'canChat': 0, 'expiringSoon': 0,
      'weekCounts': List.generate(7, (_) => 0),
      'memberRows': <Map<String, dynamic>>[],
    };
  }

  final memberProfiles = await client
      .from('profiles')
      .select('id, full_name')
      .or(memberIds.map((id) => 'id.eq.$id').join(','));

  final profileMap = <String, String>{};
  for (final p in (memberProfiles as List)) {
    profileMap[p['id'] as String] = p['full_name'] as String? ?? 'Unknown';
  }
  final totalMembers = profileMap.length;

  final rooms = await client
      .from('chat_rooms')
      .select('id')
      .or('participant_one.eq.$userId,participant_two.eq.$userId');

  final roomMemberIds = <String>{};
  for (final r in (rooms as List)) {
    final p1 = r['participant_one'] as String?;
    final p2 = r['participant_two'] as String?;
    if (p1 != null && p1 != userId) roomMemberIds.add(p1);
    if (p2 != null && p2 != userId) roomMemberIds.add(p2);
  }
  final canChat = roomMemberIds.where((id) => memberIds.contains(id)).length;

  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekCounts = List.generate(7, (i) => 0);

  final attendance = await client
      .from('attendance')
      .select('member_id, check_in_time')
      .inFilter('member_id', memberIds)
      .gte('check_in_time', weekStart.subtract(const Duration(days: 90)).toIso8601String());

  final lastCheckIn = <String, DateTime>{};
  for (final a in (attendance as List)) {
    final mid = a['member_id'] as String;
    final t = DateTime.parse(a['check_in_time'] as String);
    final day = t.weekday - 1;
    if (!t.isBefore(weekStart) && day >= 0 && day < 7) weekCounts[day]++;
    final prev = lastCheckIn[mid];
    if (prev == null || t.isAfter(prev)) lastCheckIn[mid] = t;
  }

  final memberships = await client
      .from('memberships')
      .select('member_id, plan_name, end_date')
      .or(memberIds.map((id) => 'member_id.eq.$id').join(','))
      .eq('status', 'active');

  int expiringSoon = 0;
  final expiringThreshold = now.add(const Duration(days: 7));
  final planMap = <String, String>{};
  for (final m in (memberships as List)) {
    final mid = m['member_id'] as String;
    planMap.putIfAbsent(mid, () => m['plan_name'] as String? ?? 'Daily');
    final end = DateTime.tryParse(m['end_date'] as String? ?? '');
    if (end != null && end.isBefore(expiringThreshold) && end.isAfter(now)) {
      expiringSoon++;
    }
  }

  final today = DateTime(now.year, now.month, now.day);
  final memberRows = memberIds.map((mid) {
    final last = lastCheckIn[mid];
    final lastDay = last == null ? null : DateTime(last.year, last.month, last.day);
    final daysInactive = lastDay == null ? 999 : today.difference(lastDay).inDays;
    final planName = planMap[mid] ?? 'Daily';
    return {
      'id': mid,
      'full_name': profileMap[mid] ?? 'Unknown',
      'lastCheckIn': last?.toIso8601String(),
      'daysInactive': daysInactive,
      'planName': planName,
      'flagged': daysInactive >= 7 || (planName == 'Daily' && daysInactive >= 4),
    };
  }).toList()
    ..sort((a, b) {
      final fa = a['flagged'] == true;
      final fb = b['flagged'] == true;
      if (fa != fb) return fa ? -1 : 1;
      return (b['daysInactive'] as int).compareTo(a['daysInactive'] as int);
    });

  return {
    'totalMembers': totalMembers,
    'canChat': canChat,
    'expiringSoon': expiringSoon,
    'weekCounts': weekCounts,
    'memberRows': memberRows,
  };
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(trainerDashboardProvider);
    final name = SupabaseClientService().client.auth.currentUser?.userMetadata?['full_name'] as String? ?? 'Coach';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Dashboard',
                        style: ClayTokens.headlineMedium.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: 0.38)),
                      Text(name,
                        style: ClayTokens.bodySmall.copyWith(fontSize: 13, fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary)),
                    ],
                  ),
                  Icon(CupertinoIcons.bell, color: ClayTokens.clayDarkTextTertiary, size: 20),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dataAsync.when(
                data: (data) => _DashboardContent(data: data),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    children: [
                      SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: SkeletonBox(height: 70)),
                          SizedBox(width: 8),
                          Expanded(child: SkeletonBox(height: 70)),
                          SizedBox(width: 8),
                          Expanded(child: SkeletonBox(height: 70)),
                        ],
                      ),
                      SizedBox(height: 14),
                      SkeletonBox(width: 180, height: 14),
                      SizedBox(height: 10),
                      SkeletonBox(height: 90),
                    ],
                  ),
                ),
                error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  final Map<String, dynamic> data;

  const _DashboardContent({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalMembers = data['totalMembers'] as int;
    final canChat = data['canChat'] as int;
    final expiringSoon = data['expiringSoon'] as int;
    final weekCounts = data['weekCounts'] as List<int>;
    final memberRows = data['memberRows'] as List<dynamic>;
    final maxCount = weekCounts.reduce((a, b) => a > b ? a : 1).clamp(1, 100);
    final today = DateTime.now().weekday - 1;
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      physics: const ClampingScrollPhysics(),
      children: [
          Row(
              children: [
                Expanded(child: StaggeredFadeIn(
                  index: 0,
                  child: _StatPill(
                    valueWidget: AnimatedCountUp(target: totalMembers, style: ClayTokens.headlineMedium.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayPrimaryLight)),
                    label: 'Members',
                    style: _StatStyle.purple,
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: StaggeredFadeIn(
                  index: 1,
                  child: _StatPill(
                    valueWidget: AnimatedCountUp(target: canChat, style: ClayTokens.headlineMedium.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayAccent)),
                    label: 'Can Chat',
                    style: _StatStyle.green,
                  ),
                )),
                const SizedBox(width: 8),
                Expanded(child: StaggeredFadeIn(
                  index: 2,
                  child: _StatPill(
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedCountUp(target: expiringSoon, style: ClayTokens.headlineMedium.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayWarning)),
                        const SizedBox(width: 4),
                        Icon(
                          expiringSoon > 0 ? CupertinoIcons.arrow_up_right : CupertinoIcons.arrow_down,
                          color: expiringSoon > 0 ? ClayTokens.clayWarning : ClayTokens.clayAccent,
                          size: 14,
                        ),
                      ],
                    ),
                    label: 'Exp. Soon',
                    style: _StatStyle.amber,
                  ),
                )),
              ],
            ),
          const SizedBox(height: 14),
          StaggeredFadeIn(
            index: 3,
            child: Text('Workouts This Week \u2014 All Members',
              style: ClayTokens.titleLarge.copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.41)),
          ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ClayTokens.clayDarkBorder.withAlpha(100)),
          ),
          child: Column(
            children: [
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (i) {
                    final count = weekCounts[i];
                    final pct = maxCount > 0 ? count / maxCount : 0.0;
                    final h = (pct * 64).clamp(2.0, 64.0);
                    final isToday = i == today;
                    final isFuture = i > today;
                    return Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: h,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                          color: isFuture
                              ? ClayTokens.clayDarkTextTertiary.withAlpha(30)
                              : isToday
                                  ? const Color(0xFF00F5B0)
                                  : ClayTokens.clayPrimary,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: List.generate(7, (i) {
                  return Expanded(
                    child: Text(labels[i],
                      textAlign: TextAlign.center,
                      style: ClayTokens.labelMedium.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: i == today ? const Color(0xFF00F5B0) : ClayTokens.clayDarkTextTertiary,
                        letterSpacing: 0.06,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StaggeredFadeIn(
          index: 4,
          child: Text('Members',
            style: ClayTokens.titleLarge.copyWith(fontSize: 17, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.41)),
        ),
        const SizedBox(height: 10),
        ...memberRows.map((m) => _MemberRow(member: m as Map<String, dynamic>)),
        const SizedBox(height: 16),
      ],
    );
  }
}

enum _StatStyle { purple, green, amber }

class _StatPill extends StatelessWidget {
  final Widget valueWidget;
  final String label;
  final _StatStyle style;

  const _StatPill({required this.valueWidget, required this.label, required this.style});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    switch (style) {
      case _StatStyle.purple:
        bg = ClayTokens.clayPrimary.withAlpha(15);
        border = ClayTokens.clayPrimary.withAlpha(40);
      case _StatStyle.green:
        bg = ClayTokens.clayAccent.withAlpha(15);
        border = ClayTokens.clayAccent.withAlpha(40);
      case _StatStyle.amber:
        bg = ClayTokens.clayWarning.withAlpha(15);
        border = ClayTokens.clayWarning.withAlpha(40);
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          valueWidget,
          const SizedBox(height: 2),
          Text(label, style: ClayTokens.labelMedium.copyWith(fontSize: 11, fontWeight: FontWeight.w500, color: ClayTokens.clayDarkTextTertiary, letterSpacing: 0.06)),
        ],
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Map<String, dynamic> member;

  const _MemberRow({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member['full_name'] as String? ?? 'Member';
    final plan = member['planName'] as String? ?? 'Daily';
    final days = member['daysInactive'] as int;
    final flagged = member['flagged'] == true;
    final initials = name.split(' ').map((n) => n[0]).take(2).join();
    final subtitle = days >= 999
        ? 'Never checked in'
        : 'Last check-in ${days}d ago';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClayCard(
        variant: ClayCardVariant.outlined,
        padding: ClayCardPadding.small,
        onTap: () => context.push('/trainer/members/${member['id']}'),
        child: Row(
          children: [
            ClayAvatar(initials: initials, size: ClayAvatarSize.md),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                ],
              ),
            ),
            Text(plan, style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
            const SizedBox(width: 8),
            if (flagged)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: ClayTokens.clayWarning.withAlpha(20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ClayTokens.clayWarning.withAlpha(50)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber, size: 11, color: ClayTokens.clayWarning),
                    const SizedBox(width: 3),
                    Text(
                      days >= 7 ? 'INACTIVE' : 'ABSENT',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: ClayTokens.clayWarning),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
