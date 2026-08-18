import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/providers/auth_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/notification_popup.dart';

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

  return {
    'totalMembers': totalMembers,
    'canChat': canChat,
    'expiringSoon': expiringSoon,
    'weekCounts': weekCounts,
  };
});

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isNotificationOpen = false;
  final _bellKey = GlobalKey();

  void _toggleNotifications() {
    setState(() => _isNotificationOpen = !_isNotificationOpen);
  }

  void _closeNotifications() {
    setState(() => _isNotificationOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final authAsync = ref.watch(authProvider);
                        return authAsync.when(
                          data: (profile) {
                            final fullName = profile?.fullName ?? 'Trainer';
                            final name = fullName.split(' ').first;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name,
                                    style: ClayTokens.titleLarge.copyWith(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: ClayTokens.clayDarkTextPrimary,
                                      letterSpacing: -0.41,
                                    )),
                                const SizedBox(height: 2),
                                Text(greeting,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: ClayTokens.clayDarkTextTertiary,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ],
                            );
                          },
                          loading: () => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SkeletonBox(width: 80, height: 20, borderRadius: 4),
                              const SizedBox(height: 2),
                              SkeletonBox(width: 60, height: 12, borderRadius: 4),
                            ],
                          ),
                          error: (_, __) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Trainer', style: ClayTokens.titleLarge),
                              Text(greeting, style: ClayTokens.bodySmall),
                            ],
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    NotificationBell(key: _bellKey, isMember: false, onTap: _toggleNotifications, isActive: _isNotificationOpen),
                  ],
                ),
              ),
              NotificationPopup(
                isOpen: _isNotificationOpen,
                isMember: false,
                onClose: _closeNotifications,
                bellKey: _bellKey,
              ),
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final dataAsync = ref.watch(trainerDashboardProvider);
                    return dataAsync.when(
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
                    );
                  },
                ),
              ),
            ],
          ),
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
                            ? ClayTokens.clayDarkTextTertiary.withAlpha(50)
                            : isToday
                                ? ClayTokens.clayPrimaryDark
                                : ClayTokens.clayPrimaryDark,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(7, (i) {
                  final isToday = i == today;
                  return Expanded(
                    child: Text(labels[i],
                      textAlign: TextAlign.center,
                       style: TextStyle(
                         fontSize: 10, fontWeight: FontWeight.w500,
                         color: isToday ? ClayTokens.clayPrimaryDark : ClayTokens.clayDarkTextTertiary,
                       ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
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
    late Color bg;
    switch (style) {
      case _StatStyle.purple:
        bg = ClayTokens.clayPrimaryLight.withAlpha(25);
        break;
      case _StatStyle.green:
        bg = ClayTokens.clayAccent.withAlpha(25);
        break;
      case _StatStyle.amber:
        bg = ClayTokens.clayWarning.withAlpha(25);
        break;
    }

    return ClayCard(
      variant: ClayCardVariant.elevated,
      padding: ClayCardPadding.small,
      backgroundColor: bg,
      child: Row(
        children: [
          valueWidget,
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 11, color: ClayTokens.clayDarkTextTertiary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}