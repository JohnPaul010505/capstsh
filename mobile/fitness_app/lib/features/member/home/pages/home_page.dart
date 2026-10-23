import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/providers/activity_status_provider.dart';
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
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/clay/clay_button.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/clay_area_chart.dart';
import '../../../shared/widgets/notification_popup.dart';
import '../../../shared/widgets/activity_status_badge.dart';
import '../../../shared/services/prediction_service.dart';
import '../../goals/services/goal_home_widget.dart';

// Kept alive for the whole session: independent queries run in parallel, and
// the previous result stays cached so returning to Home renders instantly
// (no skeleton) instead of blocking on ~6 sequential network round-trips.
//
// User-scoped: watches [activeUserIdProvider] so a trainer -> member account
// switch on the same device disposes the previous user's result instead of
// flashing e.g. the trainer's open attendance session as the member's ACTIVE
// membership card. Throws when signed out / mismatched so callers show the
// loading or error state rather than another user's data.
final homeDataProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, requestedUserId) async {
      final client = SupabaseClientService().client;
      final userId = ref.watch(activeUserIdProvider);
      final authUid = client.auth.currentUser?.id;
      if (requestedUserId.isEmpty ||
          userId == null ||
          authUid == null ||
          userId != authUid ||
          requestedUserId != userId) {
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
            .eq('goal_category', 'workout')
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
        final t = DateTime.parse(m['measured_at'] as String).toLocal();
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
      if (mounted) {
        _invalidateHomeData();
        _syncGoalWidget();
      }
    });
    _startRealtimeListeners();
    _startPeriodicInvalidation();
  }

  void _invalidateHomeData() {
    final memberId = ref.read(activeUserIdProvider);
    if (memberId != null) ref.invalidate(homeDataProvider(memberId));
  }

  Future<void> _syncGoalWidget() async {
    final profile = ref.read(authProvider).valueOrNull;
    if (profile?.role == 'member') {
      await GoalHomeWidget.syncForCurrentMember();
    }
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
          if (mounted) {
            _invalidateHomeData();
            ref.invalidate(memberActivityStatusProvider(userId));
          }
        });

    // Workout logs realtime listener
    _workoutSub = client
        .from('workout_logs')
        .stream(primaryKey: ['id'])
        .eq('member_id', userId)
        .listen((_) {
          if (mounted) _invalidateHomeData();
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
          _invalidateHomeData();
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
      _invalidateHomeData();
      _syncGoalWidget();
    }
    _wasHome = isHome;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _invalidateHomeData();
      _syncGoalWidget();
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
    final memberId = ref.watch(activeUserIdProvider) ?? '';
    final dataAsync = ref.watch(homeDataProvider(memberId));
    final profile = ref.watch(authProvider).valueOrNull;
    final onboardingAsync = ref.watch(needsOnboardingProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
        StaggeredFadeIn(
          index: 0,
          child: _PredictionCard(
            key: ValueKey('prediction-$memberId'),
            memberId: memberId,
          ),
        ),
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

  const _PredictionCard({super.key, required this.memberId});

  @override
  State<_PredictionCard> createState() => _PredictionCardState();
}

class _GoalForecastData {
  final Map<String, dynamic> goal;
  final double? currentWeight;
  final DateTime? deadline;
  final int daysAhead;
  final MemberForecast? forecast;

  const _GoalForecastData({
    required this.goal,
    required this.currentWeight,
    required this.deadline,
    required this.daysAhead,
    required this.forecast,
  });
}

class _PredictionCardState extends State<_PredictionCard> {
  _GoalForecastData? _data;
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _PredictionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.memberId != widget.memberId) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final client = SupabaseClientService().client;
      final goals = await client
          .from('goals')
          .select('title, goal_type, target_value, current_value, end_date')
          .eq('member_id', widget.memberId)
          .eq('status', 'active')
          .eq('goal_category', 'workout')
          .order('created_at', ascending: false)
          .limit(1);

      if (goals.isEmpty) {
        if (mounted) {
          setState(() {
            _data = null;
            _loading = false;
          });
        }
        return;
      }

      final goal = Map<String, dynamic>.from(goals.first);
      final measurements = await client
          .from('body_measurements')
          .select('weight_kg, measured_at')
          .eq('member_id', widget.memberId)
          .order('measured_at', ascending: false)
          .limit(20);
      final measuredWeight = measurements.isEmpty
          ? null
          : (measurements.first['weight_kg'] as num?)?.toDouble();
      final currentWeight =
          measuredWeight ?? (goal['current_value'] as num?)?.toDouble();
      final deadline = DateTime.tryParse(goal['end_date']?.toString() ?? '');
      final today = DateUtils.dateOnly(DateTime.now());
      final daysAhead = deadline == null
          ? 30
          : DateUtils.dateOnly(deadline).difference(today).inDays;
      MemberForecast? forecast;
      if (daysAhead > 0) {
        forecast = await PredictionService()
            .getForecast(widget.memberId, daysAhead: daysAhead)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => const MemberForecast(
                results: [],
                error: 'Prediction service timed out',
              ),
            );
        final serverWeight = forecast.byType('weight');
        if (serverWeight == null ||
            forecast.error != null ||
            serverWeight.method == 'baseline-only') {
          forecast = _localWeightForecast(measurements, daysAhead);
        }
      }

      if (!mounted) return;
      setState(() {
        _data = _GoalForecastData(
          goal: goal,
          currentWeight: currentWeight,
          deadline: deadline,
          daysAhead: daysAhead,
          forecast: forecast,
        );
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadError = 'Could not load your goal right now.';
          _loading = false;
        });
      }
    }
  }

  /// Keeps the Home forecast useful when the optional prediction API is down
  /// or unreachable from a member's phone. Uses the member's own RLS-scoped
  /// weigh-ins, the same minimum history and 5% horizon guard as the service.
  MemberForecast _localWeightForecast(List<dynamic> rows, int daysAhead) {
    final points =
        rows
            .map((row) => Map<String, dynamic>.from(row as Map))
            .where((row) => row['weight_kg'] is num)
            .map((row) {
              final date = DateTime.tryParse(
                row['measured_at']?.toString() ?? '',
              );
              return (weight: (row['weight_kg'] as num).toDouble(), date: date);
            })
            .where((point) => point.weight > 0)
            .toList()
          ..sort(
            (a, b) => (a.date ?? DateTime.fromMillisecondsSinceEpoch(0))
                .compareTo(b.date ?? DateTime.fromMillisecondsSinceEpoch(0)),
          );

    if (points.length < 3 || points.any((point) => point.date == null)) {
      return const MemberForecast(results: [], notEnoughData: true);
    }
    final firstDate = points.first.date!;
    final lastDate = points.last.date!;
    final spanDays = lastDate.difference(firstDate).inHours / 24;
    if (spanDays < 7) {
      return const MemberForecast(results: [], notEnoughData: true);
    }

    final xs = points
        .map((point) => point.date!.difference(firstDate).inHours / 24)
        .toList();
    final ys = points.map((point) => point.weight).toList();
    final count = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / count;
    final meanY = ys.reduce((a, b) => a + b) / count;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < count; i++) {
      final dx = xs[i] - meanX;
      numerator += dx * (ys[i] - meanY);
      denominator += dx * dx;
    }
    final slope = denominator == 0 ? 0.0 : numerator / denominator;
    final intercept = meanY - slope * meanX;
    var residuals = 0.0;
    var total = 0.0;
    for (var i = 0; i < count; i++) {
      residuals += math.pow(ys[i] - (intercept + slope * xs[i]), 2);
      total += math.pow(ys[i] - meanY, 2);
    }
    final r2 = total == 0 ? 0.0 : (1 - residuals / total).clamp(0.0, 1.0);
    final current = ys.last;
    final raw = intercept + slope * (xs.last + daysAhead);
    final low = math.max(0.5, current * 0.95);
    final high = current * 1.05;
    final predicted = raw.clamp(low, high).toDouble();
    final sampleFactor = math.min(1.0, (count - 1) / 4);
    final spanFactor = math.min(1.0, spanDays / 28);
    final confidence = (r2 * sampleFactor * spanFactor).clamp(0.0, 0.95);

    return MemberForecast(
      results: [
        PredictionResult(
          predictionType: 'weight',
          currentValue: current,
          predictedValue: predicted,
          unit: 'kg',
          daysAhead: daysAhead,
          confidence: confidence,
          method: 'on-device-linear-regression',
          sufficient: true,
          note: 'On-device estimate from recent weigh-ins.',
        ),
      ],
    );
  }

  String _weightLabel(double? weight) =>
      weight == null ? 'Weight not logged' : '${weight.toStringAsFixed(1)} kg';

  String _goalOutcome(_GoalForecastData data, double predictedWeight) {
    final goalType = (data.goal['goal_type'] as String? ?? '').toLowerCase();
    final target = (data.goal['target_value'] as num?)?.toDouble();
    if (target == null || target <= 0) return 'Goal target unavailable';

    if (goalType == 'lose weight') {
      final amountOver = predictedWeight - target;
      return amountOver <= 0.05
          ? 'On track for ${target.toStringAsFixed(1)} kg'
          : '${amountOver.toStringAsFixed(1)} kg above your target';
    }
    if (goalType == 'gain muscle') {
      final amountShort = target - predictedWeight;
      return amountShort <= 0.05
          ? 'On track for ${target.toStringAsFixed(1)} kg'
          : '${amountShort.toStringAsFixed(1)} kg short of your target';
    }

    final difference = predictedWeight - target;
    return difference.abs() <= 0.5
        ? 'Forecast is near your ${target.toStringAsFixed(1)} kg target'
        : 'Forecast ${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)} kg from target';
  }

  Future<void> _openWeightLog(BuildContext context) async {
    await context.push('/member/bmi');
    if (!mounted) return;
    PredictionService.clearMemberCache(widget.memberId);
    _load();
  }

  Widget _buildGoalBody(BuildContext context, _GoalForecastData data) {
    final goal = data.goal;
    final goalType = goal['goal_type'] as String? ?? 'Fitness';
    final goalTitle = (goal['title'] as String?)?.trim().isNotEmpty == true
        ? (goal['title'] as String).trim()
        : '$goalType goal';
    final target = (goal['target_value'] as num?)?.toDouble();
    final targetLabel = target == null
        ? 'Target not set'
        : 'Target ${target.toStringAsFixed(1)} kg';
    final deadlineLabel = data.deadline == null
        ? null
        : DateFormat('MMM d').format(data.deadline!);
    final prediction = data.forecast?.byType('weight');
    final hasTrend =
        prediction != null &&
        data.forecast?.notEnoughData != true &&
        prediction.method != 'baseline-only' &&
        prediction.predictedValue > 0;

    if (data.daysAhead <= 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goalTitle,
            style: TextStyle(
              fontSize: 12,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$targetLabel${deadlineLabel == null ? '' : ' \u2022 due $deadlineLabel'}',
            style: TextStyle(
              fontSize: 13,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'This goal has ended. Update it to forecast a new deadline.',
            style: TextStyle(
              fontSize: 11,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ],
      );
    }

    if (hasTrend) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goalTitle,
            style: TextStyle(
              fontSize: 12,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_weightLabel(prediction.currentValue)}  \u2192  ${_weightLabel(prediction.predictedValue)}${deadlineLabel == null ? '' : ' by $deadlineLabel'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
          if (target != null) ...[
            const SizedBox(height: 3),
            Text(
              '$targetLabel \u00b7 ${_goalOutcome(data, prediction.predictedValue)}',
              style: TextStyle(
                fontSize: 11,
                color: ClayTokens.clayDarkTextSecondary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            'Estimate based on your recent weigh-ins.',
            style: TextStyle(
              fontSize: 10,
              color: ClayTokens.clayDarkTextTertiary,
            ),
          ),
        ],
      );
    }

    final serviceFailed = data.forecast?.error != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          goalTitle,
          style: TextStyle(
            fontSize: 12,
            color: ClayTokens.clayDarkTextSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Current ${_weightLabel(data.currentWeight)} \u00b7 $targetLabel${deadlineLabel == null ? '' : ' by $deadlineLabel'}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: ClayTokens.clayDarkTextPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          serviceFailed
              ? 'Your forecast is unavailable right now.'
              : 'Log at least 3 weigh-ins over 7 days to estimate progress toward this goal.',
          style: TextStyle(
            fontSize: 11,
            color: ClayTokens.clayDarkTextSecondary,
          ),
        ),
        if (!serviceFailed) _logWeightAction(context),
      ],
    );
  }

  Widget _logWeightAction(BuildContext context) => TextButton.icon(
    onPressed: () => _openWeightLog(context),
    style: TextButton.styleFrom(
      foregroundColor: const Color(0xFFD6A5FF),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      visualDensity: VisualDensity.compact,
    ),
    icon: const Icon(Icons.monitor_weight_outlined, size: 16),
    label: const Text('Log weight'),
  );

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final Widget body;
    if (_loading) {
      body = Row(
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
              'Loading your goal forecast...',
              style: TextStyle(
                fontSize: 12,
                color: ClayTokens.clayDarkTextSecondary,
              ),
            ),
          ),
        ],
      );
    } else if (_loadError != null) {
      body = Text(
        _loadError!,
        style: TextStyle(fontSize: 12, color: ClayTokens.clayDarkTextSecondary),
      );
    } else if (data == null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create a weight goal to see your forecast.',
            style: TextStyle(
              fontSize: 13,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
          TextButton.icon(
            onPressed: () => context.push('/member/goals'),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFD6A5FF),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            ),
            icon: const Icon(Icons.flag_outlined, size: 16),
            label: const Text('Set a goal'),
          ),
        ],
      );
    } else {
      body = _buildGoalBody(context, data);
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
                  // Soft purple tile, white glyph.
                  color: ClayTokens.clayPrimaryDark,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ClayTokens.clayPrimaryLight.withAlpha(120),
                  ),
                ),
                child: const Icon(
                  Icons.insights,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI GOAL FORECAST',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: ClayTokens.clayDarkTextSecondary,
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
// days). Delegates to the app-wide [GlassSurface] so the home cards are
// literally the same material as every dashboard panel and nav bar.
class _HomeGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _HomeGlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) =>
      GlassSurface(padding: padding, child: child);
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
              // Match the weekly bars and chart lines.
              color: ClayTokens.clayPrimaryDark,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: ClayTokens.clayPrimaryLight.withAlpha(120),
              ),
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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: ClayTokens.clayDarkTextPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Active days this month',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.clayDarkTextSecondary,
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
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.fitness_center,
                        color: ClayTokens.clayDarkTextPrimary,
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
                            color: ClayTokens.clayDarkTextPrimary,
                            height: 1.0,
                          ),
                        ),
                        Row(
                          children: [
                            _timeOfDayIcon(),
                            const SizedBox(width: 6),
                            Text(
                              greeting,
                              style: TextStyle(
                                fontSize: 11,
                                color: ClayTokens.clayDarkTextSecondary,
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
              textColor: ClayTokens.clayDarkTextPrimary,
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
      color: isEvening ? ClayTokens.clayPrimaryLight : ClayTokens.clayWarning,
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

    return MemberGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
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
                        color: ClayTokens.clayDarkTextPrimary,
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
                            color: ClayTokens.clayDarkTextSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Text(
                        'Tap a bar for details',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: ClayTokens.clayDarkTextTertiary,
                        ),
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
                    color: ClayTokens.clayDarkTextSecondary,
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

    return MemberGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
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
    return MemberGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
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
                          color: ClayTokens.clayDarkTextPrimary,
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
                      color: ClayTokens.clayDarkTextSecondary,
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

    return MemberGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
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
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'BMI per month',
                    style: TextStyle(
                      fontSize: 10,
                      fontFamily: ClayTypography.headingFamily,
                      fontWeight: FontWeight.w800,
                      color: ClayTokens.clayDarkTextSecondary,
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
