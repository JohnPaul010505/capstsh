import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart';
import '../../onboarding/pages/onboarding_splash_screen.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_button.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/clay_area_chart.dart';
import '../../calendar/providers/calendar_seed_data.dart';

// Kept alive for the whole session: independent queries run in parallel, and
// the previous result stays cached so returning to Home renders instantly
// (no skeleton) instead of blocking on ~6 sequential network round-trips.
final homeDataProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final client = SupabaseClientService().client;
  final userId = client.auth.currentUser!.id;

  final profile = ref.watch(authProvider).valueOrNull;
  final today = DateTime.now();
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final yearStart = DateTime(today.year, 1, 1);
  final nextYear = DateTime(today.year + 1, 1, 1);
  final monthEnd = DateTime(today.year, today.month + 1, 0).day;

  // Fire all independent queries in parallel (ONE network latency total).
  final results = await Future.wait<dynamic>([
    // Yearly attendance (includes check_out/expires to derive today's open
    // session client-side — no extra round-trip).
    client
        .from('attendance')
        .select('check_in_time, check_in_date, check_out_time, expires_at')
        .eq('member_id', userId)
        .gte('check_in_time', yearStart.toIso8601String())
        .lt('check_in_time', nextYear.toIso8601String()),
    client
        .from('body_measurements')
        .select('weight_kg, height_cm, measured_at')
        .eq('member_id', userId)
        .gte('measured_at', yearStart.toIso8601String())
        .lt('measured_at', nextYear.toIso8601String())
        .order('measured_at', ascending: true),
    client
        .from('goals')
        .select('title')
        .eq('member_id', userId)
        .eq('status', 'active')
        .limit(1),
    client
        .from('trainer_assignments')
        .select('trainer_id')
        .eq('member_id', userId)
        .eq('status', 'active')
        .limit(1),
    client
        .from('memberships')
        .select('plan_name, end_date, status')
        .eq('member_id', userId)
        .eq('status', 'active')
        .limit(1),
    // This Week chart counts actual logged workouts (not QR check-ins).
    client
        .from('workout_logs')
        .select('logged_at')
        .eq('member_id', userId)
        .gte('logged_at', weekStart.toUtc().toIso8601String())
        .lt('logged_at', weekEnd.toUtc().toIso8601String()),
  ]);

  final yearList = results[0] as List;
  final measurements = results[1] as List;
  final goals = results[2] as List;
  final assignment = results[3] as List;
  final membershipResp = results[4] as List;
  final weekWorkouts = results[5] as List;

  final todayStr = today.toIso8601String().split('T').first;

  final isM002 = profile?.code == 'M002';
  if (isM002 && today.year == 2026 && today.month == 8 && today.day == 14) {
    final currentUserId = client.auth.currentUser!.id;
    yearList.addAll(CalendarSeedData.generateAug14Attendance(currentUserId));
    measurements.addAll(CalendarSeedData.generateAug14Measurement(currentUserId));
    weekWorkouts.addAll(CalendarSeedData.generateAug14Workouts(currentUserId));
  }

  // Workouts grouped by PH/local weekday (Mon-first). Parsing with toLocal()
  // keeps early-morning sessions (e.g. 01:17 PH = 17:17 UTC the day before)
  // on the correct weekday.
  final weekCounts = List.generate(7, (i) => 0);
  for (final w in weekWorkouts.cast<Map<String, dynamic>>()) {
    final t = DateTime.tryParse(w['logged_at'] as String? ?? '')?.toLocal();
    if (t != null && !t.isBefore(weekStart) && t.isBefore(weekEnd)) {
      weekCounts[t.weekday - 1]++;
    }
  }

  final monthlyCounts = List.generate(12, (i) => 0);
  final monthCounts = List.generate(monthEnd, (i) => 0);
  Map<String, dynamic>? openSession;
  for (final a in yearList.cast<Map<String, dynamic>>()) {
    final t = DateTime.parse(a['check_in_time'] as String);
    final day = t.day - 1;
    if (t.month - 1 >= 0 && t.month - 1 < 12) monthlyCounts[t.month - 1]++;
    if (t.month == today.month && day >= 0 && day < monthEnd) monthCounts[day]++;
    if (a['check_in_date'] == todayStr && a['check_out_time'] == null) {
      openSession ??= a;
    }
  }

  final totalWorkouts = monthCounts.reduce((a, b) => a + b);
  final activeDays = monthCounts.where((c) => c > 0).length;

  final monthlyBmis = List<double?>.generate(12, (i) => null);
  for (final m in measurements.cast<Map<String, dynamic>>()) {
    final t = DateTime.parse(m['measured_at'] as String);
    final heightCm = (m['height_cm'] as num?)?.toDouble();
    final weightKg = (m['weight_kg'] as num?)?.toDouble();
    if (heightCm != null && heightCm > 0 && weightKg != null && t.month - 1 >= 0 && t.month - 1 < 12) {
      final h = heightCm / 100;
      monthlyBmis[t.month - 1] = double.parse((weightKg / (h * h)).toStringAsFixed(1));
    }
  }

  if (isM002 && today.year == 2026 && today.month >= 1 && today.month <= 8) {
    final latestBmi = monthlyBmis[today.month - 1];
    if (latestBmi != null) {
      final baseBmi = 20.0;
      final step = (latestBmi - baseBmi) / (today.month - 1);
      for (var month = 1; month < today.month; month++) {
        if (monthlyBmis[month - 1] == null) {
          monthlyBmis[month - 1] = double.parse((baseBmi + step * (month - 1)).toStringAsFixed(1));
        }
      }
    }
  }

  final activeGoal = goals.isNotEmpty ? goals[0]['title'] as String? : null;

  Map<String, dynamic>? trainerProfile;
  if (assignment.isNotEmpty) {
    final trainerId = assignment[0]['trainer_id'] as String;
    final trainerResp = await client
        .from('profiles')
        .select('id, full_name, avatar_url')
        .eq('id', trainerId)
        .single();
    trainerProfile = trainerResp;
  }

  Map<String, dynamic>? membership;
  if (membershipResp.isNotEmpty) {
    membership = membershipResp[0];
  }

  return {
    'profile': profile,
    'weekCounts': weekCounts,
    'maxWeek': weekCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100),
    'monthlyCounts': monthlyCounts,
    'maxMonth': monthlyCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100),
    'monthlyWeights': monthlyBmis,
    'totalWorkouts': totalWorkouts,
    'activeDays': activeDays,
    'activeGoal': activeGoal,
    'trainer': trainerProfile,
    'membership': membership,
    'openSession': openSession,
  };
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  GoRouter? _router;
  bool _wasHome = true;

  @override
  void initState() {
    super.initState();
    // Refresh on every visit while showing the cached data instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(homeDataProvider);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Home stays alive in the indexed-stack shell, so initState only fires
    // once. Watch the router so returning to the Home tab refetches the data.
    if (_router == null) {
      _router = GoRouter.of(context);
      _router!.routerDelegate.addListener(_onRouteChanged);
    }
  }

  void _onRouteChanged() {
    final isHome = _router!.routerDelegate.currentConfiguration.uri.path == '/member/home';
    if (isHome && !_wasHome && mounted) {
      ref.invalidate(homeDataProvider);
    }
    _wasHome = isHome;
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(homeDataProvider);
    final profile = ref.watch(authProvider).valueOrNull;
    final onboardingAsync = ref.watch(needsOnboardingProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: onboardingAsync.when(
            skipLoadingOnRefresh: true,
            data: (needsOnboarding) => needsOnboarding
                ? const OnboardingSplashScreen()
                : dataAsync.when(
                    skipLoadingOnRefresh: true,
                    data: (data) => HomeContent(data: data, profile: profile),
                    loading: () => const _LoadingState(),
                    error: (e, _) => _ErrorState(message: e.toString()),
                  ),
            loading: () => const _LoadingState(),
            error: (e, _) => _ErrorState(message: e.toString()),
          ),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const HomeSkeleton();
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
            Icon(Icons.cloud_download_outlined, color: Color(0xFF8E8E93), size: 48),
            const SizedBox(height: 12),
            Text('Something went wrong', style: ClayTokens.titleMedium),
            const SizedBox(height: 4),
            Text(message, style: ClayTokens.bodySmall, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatelessWidget {
  final Map<String, dynamic> data;
  final dynamic profile;

  const HomeContent({super.key, required this.data, this.profile});

  @override
  Widget build(BuildContext context) {
    final weekCounts = data['weekCounts'] as List<int>;
    final monthlyCounts = data['monthlyCounts'] as List<int>;
    final monthlyWeights = data['monthlyWeights'] as List<double?>;
    final totalWorkouts = data['totalWorkouts'] as int;
    final activeDays = data['activeDays'] as int;
    final trainer = data['trainer'] as Map<String, dynamic>?;
    final membership = data['membership'] as Map<String, dynamic>?;
    final openSession = data['openSession'] as Map<String, dynamic>?;
    final name = profile?.fullName ?? 'there';
    final firstName = name.split(' ').first;
    final initials = name.isNotEmpty ? name.split(' ').map((n) => n[0]).take(2).join() : '?';
    final avatarUrl = profile?.avatarUrl;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final maxCount = weekCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100);

    final planName = membership?['plan_name'] as String?;
    final showMembershipCard = membership != null && (planName != 'Daily' || openSession != null);
    final offset = showMembershipCard ? 1 : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
      physics: const ClampingScrollPhysics(),
      children: [
            const SizedBox(height: 14),
            _GreetingRow(
              greeting: greeting,
              firstName: firstName,
              initials: initials,
              imageUrl: avatarUrl,
              onAvatarTap: () => context.push('/member/settings'),
            ),
            const SizedBox(height: 12),
            if (showMembershipCard)
              StaggeredFadeIn(index: 0, child: _MembershipCard(membership: membership, openSession: openSession)),
            if (showMembershipCard) const SizedBox(height: 8),
            StaggeredFadeIn(index: offset, child: _MonthSummary(totalWorkouts: totalWorkouts, activeDays: activeDays)),
            const SizedBox(height: 8),
            StaggeredFadeIn(index: 1 + offset, child: _WeekChart(weekCounts: weekCounts, maxCount: maxCount)),
            const SizedBox(height: 8),
            StaggeredFadeIn(index: 2 + offset, child: _YearChart(
              monthlyCounts: monthlyCounts,
              totalWorkouts: totalWorkouts,
              yearLabel: '${DateTime.now().year}',
            )),
            const SizedBox(height: 8),
            StaggeredFadeIn(index: 3 + offset, child: _GrowthChart(monthlyWeights: monthlyWeights)),
            const SizedBox(height: 8),
            if (trainer != null) ...[
              StaggeredFadeIn(index: 4 + offset, child: _TrainerCard(trainer: trainer)),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
          ],
    );
  }
}

class _GreetingRow extends StatelessWidget {
  final String greeting;
  final String firstName;
  final String initials;
  final String? imageUrl;
  final VoidCallback onAvatarTap;

  const _GreetingRow({
    required this.greeting,
    required this.firstName,
    required this.initials,
    this.imageUrl,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(firstName, style: ClayTokens.displaySmall.copyWith(letterSpacing: 0, color: Color(0xFFA78BFA))),
            const SizedBox(height: 2),
            Row(
              children: [
                const AnimatedPulseDot(),
                const SizedBox(width: 5),
                Text(greeting, style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        ClayAvatar(
          imageUrl: imageUrl,
          initials: initials,
          size: ClayAvatarSize.md,
          backgroundColor: Colors.transparent,
          onTap: onAvatarTap,
        ),
      ],
    );
  }
}

class _MembershipCard extends StatefulWidget {
  final Map<String, dynamic> membership;
  final Map<String, dynamic>? openSession;

  const _MembershipCard({required this.membership, this.openSession});

  @override
  State<_MembershipCard> createState() => _MembershipCardState();
}

class _MembershipCardState extends State<_MembershipCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final plan = widget.membership['plan_name'] as String? ?? 'Basic';
    if (plan == 'Daily' && widget.openSession?['expires_at'] != null) {
      _timer = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatCountdown(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Session expired';
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    return '$hours h ${minutes.toString().padLeft(2, '0')} m';
  }

  @override
  Widget build(BuildContext context) {
    final membership = widget.membership;
    final openSession = widget.openSession;
    final plan = membership['plan_name'] as String? ?? 'Basic';
    final endDate = membership['end_date'] as String?;
    final status = membership['status'] as String? ?? 'active';
    final formattedDate = endDate != null && endDate.length >= 10
        ? endDate.substring(0, 10)
        : 'N/A';

    final isActive = status == 'active';
    final isDaily = plan == 'Daily';
    final statusColor = isActive ? ClayTokens.clayAccent : ClayTokens.clayWarning;

    final subtitle = isDaily && openSession != null
        ? 'Expires in ${_formatCountdown(DateTime.parse(openSession['expires_at'] as String))}'
        : 'Valid until $formattedDate';

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MEMBERSHIP', style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                const SizedBox(height: 3),
                Text(plan, style: ClayTokens.titleLarge.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: ClayTokens.bodySmall.copyWith(
                  color: isDaily ? ClayTokens.clayWarning : ClayTokens.clayDarkTextTertiary,
                )),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor.withAlpha(60)),
            ),
            child: Text(
              isActive ? 'ACTIVE' : status.toUpperCase(),
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekChart extends StatefulWidget {
  final List<int> weekCounts;
  final int maxCount;

  const _WeekChart({required this.weekCounts, required this.maxCount});

  @override
  State<_WeekChart> createState() => _WeekChartState();
}

class _WeekChartState extends State<_WeekChart> {
  int? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday - 1;

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('This Week', style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                  const SizedBox(height: 1),
                  if (_selectedDay != null)
                    AnimatedOpacity(
                      duration: ClayTokens.normal,
                      opacity: 1.0,
                      child: Text(
                        '${labels[_selectedDay!]}: ${widget.weekCounts[_selectedDay!]} workout${widget.weekCounts[_selectedDay!] == 1 ? '' : 's'}',
                        style: TextStyle(fontSize: 10, color: ClayTokens.clayPrimaryLight, fontWeight: FontWeight.w600),
                      ),
                    )
                  else
                    Text('Tap a bar for details', style: TextStyle(fontSize: 10, color: ClayTokens.clayDarkTextTertiary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = widget.weekCounts[i];
                final pct = widget.maxCount > 0 ? (count / widget.maxCount) : 0.0;
                final barHeight = (pct * 52).clamp(2.0, 52.0);
                final isToday = i == today;
                final isFuture = i > today;
                final isSelected = i == _selectedDay;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedDay = _selectedDay == i ? null : i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: isSelected ? (barHeight + 6).clamp(2.0, 58.0) : barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      color: isFuture
                          ? ClayTokens.clayDarkTextTertiary.withAlpha(50)
                          : isToday
                              ? ClayTokens.clayPrimaryDark
                              : ClayTokens.clayPrimaryDark,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 5),
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
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Widget valueWidget;
  final String label;

  const _StatCard({
    required this.icon, required this.iconBg, required this.iconColor,
    required this.valueWidget, required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: ClayCard(
        variant: ClayCardVariant.elevated,
        padding: ClayCardPadding.small,
        child: Row(
          children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 15, color: iconColor),
            ),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                valueWidget,
                Text(label, style: TextStyle(fontSize: 9, color: ClayTokens.clayDarkTextTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerCard extends StatelessWidget {
  final Map<String, dynamic> trainer;

  const _TrainerCard({required this.trainer});

  @override
  Widget build(BuildContext context) {
    final name = trainer['full_name'] as String? ?? 'Your Trainer';
    final initials = name.split(' ').map((n) => n[0]).take(2).join();

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        children: [
          Row(
            children: [
              ClayAvatar(
                initials: initials,
                size: ClayAvatarSize.md,
                showOnlineIndicator: true,
                isOnline: true,
                onlineColor: ClayTokens.clayAccent,
              ),
              const SizedBox(width: 10              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                    const SizedBox(height: 1),
                    Text('Your Trainer', style: ClayTokens.bodySmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
                    const SizedBox(height: 3),
                    const _StarRow(),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClayButton(
            label: 'Ask a question',
            onPressed: () => context.go('/member/chat'),
            style: ClayButtonStyle.primary,
            fullWidth: true,
            size: ClayButtonSize.small,
          ),
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (i) {
        return Icon(
          i < 4 ? Icons.star : Icons.star_half,
          color: const Color(0xFFFF9500), size: 10,
        );
      }),
    );
  }
}

const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class _YearChart extends StatelessWidget {
  final List<int> monthlyCounts;
  final int totalWorkouts;
  final String yearLabel;

  const _YearChart({
    required this.monthlyCounts,
    required this.totalWorkouts,
    required this.yearLabel,
  });

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('This Month', style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                      const SizedBox(width: 6),
                      Text(yearLabel, style: TextStyle(fontSize: 13, color: ClayTokens.clayPrimaryDark, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimaryLight.withAlpha(25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: ClayTokens.clayPrimaryLight.withAlpha(50)),
                ),
                child: Text('Total: $totalWorkouts', style: TextStyle(fontSize: 10, color: ClayTokens.clayPrimaryLight, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MonthlyValues(monthlyCounts: monthlyCounts),
        ],
      ),
    );
  }
}

/// Builds the nullable value list for the year chart: past months keep their
/// real count (including 0 when there were no check-ins), the in-progress
/// current month only shows when the member has already checked in, and
/// future months have no point at all.
class _MonthlyValues extends StatelessWidget {
  final List<int> monthlyCounts;

  const _MonthlyValues({required this.monthlyCounts});

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now().month - 1;
    final values = List<double?>.generate(12, (i) {
      if (i > current) return null;
      if (i == current && monthlyCounts[i] == 0) return null;
      return monthlyCounts[i].toDouble();
    });
    return ClayAreaChart(
      values: values,
      labels: _monthShort,
      strokeColor: ClayTokens.clayPrimaryDark,
      legendLabel: 'Check-ins per month',
      showYAxis: false,
      showValueLabels: true,
    );
  }
}

class _GrowthChart extends StatelessWidget {
  final List<double?> monthlyWeights;

  const _GrowthChart({required this.monthlyWeights});

  @override
  Widget build(BuildContext context) {
    final weights = monthlyWeights.whereType<double>().toList();
    final latestWeight = weights.isEmpty ? null : weights.last;

    return ClayCard(
      variant: ClayCardVariant.outlined,
      padding: ClayCardPadding.medium,
      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Growth Over Time', style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary)),
                  const SizedBox(height: 2),
                  Text('BMI per month', style: TextStyle(fontSize: 10, color: ClayTokens.clayDarkTextTertiary)),
                ],
              ),
              if (latestWeight != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayPrimaryLight.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: ClayTokens.clayPrimaryLight.withAlpha(50)),
                  ),
                  child: Text(latestWeight.toStringAsFixed(1), style: TextStyle(fontSize: 10, color: ClayTokens.clayPrimaryLight, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClayAreaChart(
            values: monthlyWeights,
            labels: _monthShort,
            strokeColor: ClayTokens.clayPrimaryDark,
            emptyMessage: 'No BMI data yet',
            showValueLabels: true,
          ),
        ],
      ),
    );
  }
}

class _MonthSummary extends StatelessWidget {
  final int totalWorkouts;
  final int activeDays;

  const _MonthSummary({required this.totalWorkouts, required this.activeDays});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatCard(
          icon: Icons.fitness_center,
          iconBg: ClayTokens.clayPrimaryLight.withAlpha(30),
          iconColor: ClayTokens.clayPrimaryLight,
          valueWidget: AnimatedCountUp(
            target: totalWorkouts,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ClayTokens.clayDarkTextPrimary),
          ),
          label: 'Workouts this month',
        ),
        const SizedBox(width: 8),
        _StatCard(
          icon: Icons.calendar_month,
          iconBg: ClayTokens.clayPrimaryDark.withAlpha(30),
          iconColor: ClayTokens.clayPrimaryDark,
          valueWidget: AnimatedCountUp(
            target: activeDays,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ClayTokens.clayDarkTextPrimary),
          ),
          label: 'Active days',
        ),
      ],
    );
  }
}
