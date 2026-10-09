import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/providers/auth_provider.dart';
import 'package:shared/services/supabase_client.dart'
    show SupabaseClientService;
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/animations.dart'
    show StaggeredFadeIn, AnimatedCountUp;
import '../../onboarding/pages/onboarding_splash_screen.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_button.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/clay_area_chart.dart';
import '../../../shared/widgets/notification_popup.dart';
import '../../../shared/widgets/activity_status_badge.dart';
import '../../../shared/services/prediction_service.dart';

// Kept alive for the whole session: independent queries run in parallel, and
// the previous result stays cached so returning to Home renders instantly
// (no skeleton) instead of blocking on ~6 sequential network round-trips.
//
// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
// switch on the same device disposes the previous user's result instead of
// flashing e.g. the trainer's open attendance session as the member's ACTIVE
// membership card. Throws when signed out / mismatched so callers show the
// loading or error state rather than another user's data.
final homeDataProvider = FutureProvider.autoDispose<Map<String, dynamic>>((
  ref,
) async {
  final client = SupabaseClientService().client;
  final userId = ref.watch(activeUserIdProvider);
  final authUid = client.auth.currentUser?.id;
  if (userId == null || authUid == null || userId != authUid) {
    throw Exception('Signed out — please log in again.');
  }

  final profile = ref.watch(authProvider).valueOrNull;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final yearStart = DateTime(today.year, 1, 1);
  final nextYear = DateTime(today.year + 1, 1, 1);

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
  ]);

  final yearList = results[0] as List;
  final measurements = results[1] as List;
  final goals = results[2] as List;
  final assignment = results[3] as List;

  // This Week counts COMPLETED workout sessions from `workout_logs` — one row
  // per exercise, so a session is a distinct `workout_name` + local date.
  // QR attendance is presence, not movement: never mix the two.
  // toLocal() keeps early-morning check-ins (e.g. 01:17 PH = 17:17 UTC the
  // day before) on the correct weekday.
  final weekCounts = List.generate(7, (i) => 0);
  final completedSessions = <String>{};
  for (final row
      in await client
          .from('workout_logs')
          .select('workout_name, logged_at')
          .eq('member_id', userId)
          .gte('logged_at', weekStart.toUtc().toIso8601String())
          .lt('logged_at', weekEnd.toUtc().toIso8601String())
          .order('logged_at', ascending: false)) {
    final name = (row['workout_name'] as String?)?.trim() ?? '';
    final loggedAt = DateTime.tryParse(row['logged_at'] as String? ?? '');
    if (name.isEmpty || loggedAt == null) continue;
    // A completed workout = a distinct (workout, local date) pair: a single
    // session spans one or more exercise rows in `workout_logs`.
    final sessionKey = '$name|${loggedAt.toLocal()}';
    if (completedSessions.add(sessionKey)) {
      final date = DateTime.parse(sessionKey.split('|')[1]);
      if (date.isAfter(weekStart) && date.isBefore(weekEnd)) {
        weekCounts[date.weekday - 1]++;
      }
    }
  }

  final monthlyCounts = List.generate(12, (i) => 0);
  for (final a in yearList.cast<Map<String, dynamic>>()) {
    final t = DateTime.parse(a['check_in_time'] as String);
    if (t.month - 1 >= 0 && t.month - 1 < 12) monthlyCounts[t.month - 1]++;
  }

  // The Total pill sums every month plotted in the year chart (the whole
  // year total), not just the current month.
  final totalWorkouts = monthlyCounts.reduce((a, b) => a + b);

  // Active-day accounting for THIS MONTH, from REAL attendance only.
  //
  // Rule: distinct `check_in_date` values inside the current local month,
  // already member-scoped by the `.eq('member_id', ...)` query above.
  // Workout logs are exercise evidence, not presence, so they never feed
  // this count. Distinct dates prevent the same day being counted twice.
  final activeDates = <String>{};
  final monthPrefix =
      '${today.year.toString().padLeft(4, '0')}-'
      '${today.month.toString().padLeft(2, '0')}';
  for (final a in yearList.cast<Map<String, dynamic>>()) {
    final checkInDate = a['check_in_date'];
    if (checkInDate is String && checkInDate.startsWith(monthPrefix)) {
      activeDates.add(checkInDate);
    }
  }
  final activeDays = activeDates.length;

  final monthlyBmis = List<double?>.generate(12, (i) => null);
  for (final m in measurements.cast<Map<String, dynamic>>()) {
    final t = DateTime.parse(m['measured_at'] as String);
    final heightCm = (m['height_cm'] as num?)?.toDouble();
    final weightKg = (m['weight_kg'] as num?)?.toDouble();
    if (heightCm != null &&
        heightCm > 0 &&
        weightKg != null &&
        t.month - 1 >= 0 &&
        t.month - 1 < 12) {
      final h = heightCm / 100;
      monthlyBmis[t.month - 1] = double.parse(
        (weightKg / (h * h)).toStringAsFixed(1),
      );
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
  };
});

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  GoRouter? _router;
  bool _wasHome = true;
  StreamSubscription? _attendanceSub;
  StreamSubscription? _workoutSub;
  String? _listeningUserId;
  Timer? _periodicInvalidateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Refresh on every visit while showing the cached data instantly.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(homeDataProvider);
    });
    _startRealtimeListeners();
    _startPeriodicInvalidation();
  }

  void _startRealtimeListeners() {
    final userId = SupabaseClientService().client.auth.currentUser?.id;
    if (userId == null) return;
    if (_listeningUserId == userId) return;
    _attendanceSub?.cancel();
    _workoutSub?.cancel();
    _listeningUserId = userId;

    final client = SupabaseClientService().client;

    // Attendance realtime listener
    _attendanceSub = client
        .from('attendance')
        .stream(primaryKey: ['id'])
        .eq('member_id', userId)
        .listen((_) {
          if (mounted) ref.invalidate(homeDataProvider);
        });

    // Workout logs realtime listener
    _workoutSub = client
        .from('workout_logs')
        .stream(primaryKey: ['id'])
        .eq('member_id', userId)
        .listen((_) {
          if (mounted) ref.invalidate(homeDataProvider);
        });
  }

  void _startPeriodicInvalidation() {
    _periodicInvalidateTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        // Only invalidate if the page is currently visible
        final isHome =
            _router?.routerDelegate.currentConfiguration.uri.path ==
            '/member/home';
        if (isHome) {
          ref.invalidate(homeDataProvider);
        }
      }
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
    final isHome =
        _router!.routerDelegate.currentConfiguration.uri.path == '/member/home';
    if (isHome && !_wasHome && mounted) {
      ref.invalidate(homeDataProvider);
    }
    _wasHome = isHome;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(homeDataProvider);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouteChanged);
    _attendanceSub?.cancel();
    _workoutSub?.cancel();
    _periodicInvalidateTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Re-subscribe realtime listeners if the account changed (trainer ->
    // member on the same device). initState only fires once because Home
    // stays alive in the indexed-stack shell.
    final authUid = SupabaseClientService().client.auth.currentUser?.id;
    if (authUid != null && authUid != _listeningUserId) {
      _startRealtimeListeners();
    }
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
            Icon(
              Icons.cloud_download_outlined,
              color: Color(0xFF8E8E93),
              size: 48,
            ),
            const SizedBox(height: 12),
            Text('Something went wrong', style: ClayTokens.titleMedium),
            const SizedBox(height: 4),
            Text(
              message,
              style: ClayTokens.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  final Map<String, dynamic> data;
  final dynamic profile;

  const HomeContent({super.key, required this.data, this.profile});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
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
    final data = widget.data;
    final profile = widget.profile;
    final weekCounts = data['weekCounts'] as List<int>;
    final monthlyCounts = data['monthlyCounts'] as List<int>;
    final monthlyWeights = data['monthlyWeights'] as List<double?>;
    final totalWorkouts = data['totalWorkouts'] as int;
    final activeDays = data['activeDays'] as int;
    final trainer = data['trainer'] as Map<String, dynamic>?;
    final name = profile?.fullName ?? 'there';
    final firstName = name.split(' ').first;
    final initials = name.isNotEmpty
        ? name.split(' ').map((n) => n[0]).take(2).join()
        : '?';
    final avatarUrl = profile?.avatarUrl;
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final maxCount = weekCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100);

    // Always the signed-in user: profile can lag one frame behind on a
    // trainer -> member switch, and the old id would light the fire badge
    // with the previous account's attendance.
    final memberId =
        SupabaseClientService().client.auth.currentUser?.id ?? profile?.id;

    return ListView(
      // extendBody already reserves the nav-bar height via SafeArea;
      // this is just a small breathing buffer above the pill.
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      physics: const ClampingScrollPhysics(),
      children: [
        const SizedBox(height: 14),
        _GreetingRow(
          greeting: greeting,
          firstName: firstName,
          initials: initials,
          imageUrl: avatarUrl,
          onAvatarTap: () => context.push('/member/settings'),
          onBellTap: _toggleNotifications,
          isNotificationOpen: _isNotificationOpen,
          bellKey: _bellKey,
          memberId: memberId,
        ),
        NotificationPopup(
          isOpen: _isNotificationOpen,
          isMember: true,
          onClose: _closeNotifications,
          bellKey: _bellKey,
        ),
        const SizedBox(height: 12),
        StaggeredFadeIn(index: 0, child: _PredictionCard(memberId: memberId)),
        const SizedBox(height: 8),
        StaggeredFadeIn(
          index: 1,
          child: _ActiveDaysCard(activeDays: activeDays, memberId: memberId),
        ),
        const SizedBox(height: 8),
        StaggeredFadeIn(
          index: 2,
          child: _WeekChart(weekCounts: weekCounts, maxCount: maxCount),
        ),
        const SizedBox(height: 8),
        StaggeredFadeIn(
          index: 3,
          child: _YearChart(
            monthlyCounts: monthlyCounts,
            totalWorkouts: totalWorkouts,
            yearLabel: '${DateTime.now().year}',
          ),
        ),
        const SizedBox(height: 8),
        StaggeredFadeIn(
          index: 4,
          child: _GrowthChart(monthlyWeights: monthlyWeights),
        ),
        const SizedBox(height: 8),
        if (trainer != null) ...[
          StaggeredFadeIn(index: 5, child: _TrainerCard(trainer: trainer)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}

class _PredictionCard extends StatefulWidget {
  final String memberId;

  const _PredictionCard({required this.memberId});

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _PredictionCardState extends State<_PredictionCard> {
  MemberForecast? _forecast;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final forecast = await PredictionService().getForecast(widget.memberId);
    if (mounted) setState(() => _forecast = forecast);
  }

  @override
  Widget build(BuildContext context) {
    final forecast = _forecast;

    Widget body;
    if (forecast == null) {
      body = const Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFD6A5FF),
            ),
          ),
          SizedBox(width: 10),
          Flexible(
            child: Text(
              'Forecasting your progress...',
              style: TextStyle(fontSize: 12, color: Color(0xFFB9B9C2)),
            ),
          ),
        ],
      );
    } else if (forecast.notEnoughData) {
      body = const Text(
        'Log body measurements and check in a few times to unlock your AI progress forecast.',
        style: TextStyle(fontSize: 12, color: Color(0xFFB9B9C2)),
      );
    } else if (forecast.error != null || forecast.results.isEmpty) {
      body = Text(
        forecast.error ?? 'No forecast available right now.',
        style: const TextStyle(fontSize: 12, color: Color(0xFFB9B9C2)),
      );
    } else {
      final weight = forecast.byType('weight');
      // Weight only: body fat is not forecast because no screen records it.
      body = weight == null
          ? Text(
              'Keep logging weigh-ins — a forecast needs at least 3 readings over 7+ days.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFB9B9C2)),
            )
          : _ForecastRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Weight',
              current:
                  '${weight.currentValue.toStringAsFixed(1)} ${weight.unit}',
              predicted:
                  '${weight.predictedValue.toStringAsFixed(1)} ${weight.unit} in ${weight.daysAhead} days',
              confidence: weight.confidence,
            );
    }

    return _HomeGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  // Solid purple badge, white glyph (design pass).
                  color: const Color(0xFF7C3AED),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA78BFA)),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI PROGRESS FORECAST',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFD6D6DC),
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          body,
        ],
      ),
    );
  }
}

// Shared glass surface for the two top home cards (AI forecast + active
// days). The frosted blur is clipped to the rounded card and the fill is
// translucent, so the neon glow behind the list shows through — matching
// the admin/login glass language. The inner top highlight is the lit edge
// that makes glass read as glass.
class _HomeGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _HomeGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x8C1B1E41), Color(0x66140F2A)],
            ),
            border: Border.all(color: const Color(0x33BF5AF2)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2EBF5AF2),
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Stack(
            children: [
              child,
              Positioned(
                top: 0,
                left: 14,
                right: 14,
                child: IgnorePointer(
                  child: Container(
                    height: 1,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0x00FFFFFF),
                          Color(0x59FFFFFF),
                          Color(0x00FFFFFF),
                        ],
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

// Full-width "Active days" stat card with the live fire streak badge,
// matching the glass surface of the AI forecast card above it. Every text
// run is Flexible/Expanded and the badge is a fixed box, so the row can
// never overflow.
class _ActiveDaysCard extends StatelessWidget {
  final int activeDays;
  final String memberId;

  const _ActiveDaysCard({required this.activeDays, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return _HomeGlassCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              // Solid purple badge, white glyph (design pass).
              color: const Color(0xFF7C3AED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFA78BFA)),
            ),
            child: const Icon(
              Icons.event_available,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedCountUp(
                  target: activeDays,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Active days this month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFD6D6DC),
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ActivityStatusBadgeCompact(memberId: memberId, size: 46),
        ],
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String current;
  final String predicted;
  final double confidence;

  const _ForecastRow({
    required this.icon,
    required this.label,
    required this.current,
    required this.predicted,
    required this.confidence,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFFA1A1AA)),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFFB9B9C2)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$current → $predicted',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(confidence * 100).toStringAsFixed(0)}%',
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Color(0xFF30D158),
          ),
        ),
      ],
    );
  }
}

class _GreetingRow extends ConsumerWidget {
  final String greeting;
  final String firstName;
  final String initials;
  final String? imageUrl;
  final VoidCallback onAvatarTap;
  final VoidCallback onBellTap;
  final bool isNotificationOpen;
  final GlobalKey bellKey;
  final String memberId;

  const _GreetingRow({
    required this.greeting,
    required this.firstName,
    required this.initials,
    this.imageUrl,
    required this.onAvatarTap,
    required this.onBellTap,
    required this.isNotificationOpen,
    required this.bellKey,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Login-screen logo beside the name: sized to match the
              // profile avatar (ClayAvatarSize.md = 44) and nudged down a
              // little so it sits optically level with the name + greeting
              // block instead of riding high. The errorBuilder fallback
              // keeps a missing asset from ever throwing.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.fitness_center,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Name and greeting share one tight column: the greeting
                  // sits directly under the name with no extra gap, and both
                  // start at the same left edge (44 logo + 8 gap = 52px).
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ClayTokens.displaySmall.copyWith(
                            letterSpacing: 0,
                            color: Colors.white,
                            height: 1.0,
                          ),
                        ),
                        Row(
                          children: [
                            _timeOfDayIcon(),
                            const SizedBox(width: 6),
                            Text(
                              greeting,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Row(
          children: [
            NotificationBell(
              key: bellKey,
              isMember: true,
              onTap: onBellTap,
              isActive: isNotificationOpen,
            ),
            const SizedBox(width: 12),
            ClayAvatar(
              imageUrl: imageUrl,
              initials: initials,
              size: ClayAvatarSize.md,
              backgroundColor: ClayTokens.clayDarkSurface,
              borderColor: Colors.transparent,
              borderWidth: 0,
              textColor: Colors.white,
              onTap: onAvatarTap,
            ),
          ],
        ),
      ],
    );
  }

  /// Time-of-day icon next to the greeting: sun while it's still daylight
  /// (morning AND afternoon), moon only once the greeting turns to evening
  /// at 17:00 — the same threshold as the greeting text, so an afternoon
  /// screen never shows a night icon. Amber sun / violet moon instead of
  /// plain white.
  Widget _timeOfDayIcon() {
    final hour = DateTime.now().hour;
    final isEvening = hour >= 17;
    return Icon(
      isEvening ? Icons.nights_stay : Icons.wb_sunny,
      size: 16,
      color: isEvening
          ? ClayTokens.clayPrimaryLight
          : ClayTokens.clayWarning,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ClayTokens.titleMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    if (_selectedDay != null)
                      AnimatedOpacity(
                        duration: ClayTokens.normal,
                        opacity: 1.0,
                        child: Text(
                          '${labels[_selectedDay!]}: ${widget.weekCounts[_selectedDay!]} workout${widget.weekCounts[_selectedDay!] == 1 ? '' : 's'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Tap a bar for details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10, color: Colors.white),
                      ),
                  ],
                ),
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
                final pct = widget.maxCount > 0
                    ? (count / widget.maxCount)
                    : 0.0;
                final barHeight = (pct * 52).clamp(2.0, 52.0);
                final isToday = i == today;
                final isFuture = i > today;
                final isSelected = i == _selectedDay;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _selectedDay = _selectedDay == i ? null : i,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: isSelected
                          ? (barHeight + 6).clamp(2.0, 58.0)
                          : barHeight,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
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
              return Expanded(
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
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
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: ClayTokens.titleMedium.copyWith(
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Your Trainer',
                      style: ClayTokens.bodySmall.copyWith(
                        color: ClayTokens.clayDarkTextTertiary,
                      ),
                    ),
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
            onPressed: () => context.push('/member/chat'),
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
          color: const Color(0xFFFF9500),
          size: 10,
        );
      }),
    );
  }
}

const _monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

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
                      Text(
                        'This Month',
                        style: ClayTokens.titleMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        yearLabel,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: ClayTypography.headingFamily,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFA78BFA),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Check-ins per month',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Total: $totalWorkouts',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: ClayAreaChart(
        values: values,
        labels: _monthShort,
        strokeColor: ClayTokens.clayPrimaryDark,
        showYAxis: false,
        showValueLabels: true,
        // Purple dot with a matching ring (no white halo) so the point under
        // each number reads purple, per the member-home design pass.
        dotColor: ClayTokens.clayPrimary,
        dotRingColor: ClayTokens.clayPrimaryDark,
      ),
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
                  Text(
                    'Growth Over Time',
                    style: ClayTokens.titleMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BMI per month',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: ClayTypography.headingFamily,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
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
                    latestWeight.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: ClayAreaChart(
              values: monthlyWeights,
              labels: _monthShort,
              strokeColor: ClayTokens.clayPrimaryDark,
              emptyMessage: 'No BMI data yet',
              showValueLabels: true,
              // Match the "This Month" chart: purple dot, no white halo.
              dotColor: ClayTokens.clayPrimary,
              dotRingColor: ClayTokens.clayPrimaryDark,
            ),
          ),
        ],
      ),
    );
  }
}
