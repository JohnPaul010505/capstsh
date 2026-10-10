import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/clay/clay_card.dart';
import '../../../shared/widgets/clay/clay_avatar.dart';
import '../../../shared/widgets/clay_area_chart.dart';
import '../../../member/calendar/widgets/calendar_flip_sheet.dart';
import '../../../shared/widgets/activity_status_badge.dart';

final memberProgressDataProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, memberId) async {
  final client = SupabaseClientService().client;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final weekEnd = weekStart.add(const Duration(days: 7));
  final yearStart = DateTime(today.year, 1, 1);
  final nextYear = DateTime(today.year + 1, 1, 1);
  final results = await Future.wait([
    // Yearly attendance feeds the This Month chart only — the same source
    // the member's own Home uses for it (QR presence binned per month).
    client
        .from('attendance')
        .select('check_in_time')
        .eq('member_id', memberId)
        .gte('check_in_time', yearStart.toUtc().toIso8601String())
        .lt('check_in_time', nextYear.toUtc().toIso8601String()),
    // This Week's completed workout sessions — the SAME series the member's
    // own Home plots, so both screens always show identical numbers (QR
    // attendance is presence, not movement; it never feeds the week bars).
    client
        .from('workout_logs')
        .select('workout_name, logged_at')
        .eq('member_id', memberId)
        .gte('logged_at', weekStart.toUtc().toIso8601String())
        .lt('logged_at', weekEnd.toUtc().toIso8601String())
        .order('logged_at', ascending: false),
    client
        .from('body_measurements')
        .select('weight_kg, height_cm, measured_at')
        .eq('member_id', memberId)
        .gte('measured_at', yearStart.toUtc().toIso8601String())
        .lt('measured_at', nextYear.toUtc().toIso8601String())
        .order('measured_at', ascending: true),
    client
        .from('profiles')
        .select('id, full_name, email, avatar_url')
        .eq('id', memberId)
        .single(),
  ]);

  final yearAttendance = results[0] as List;
  final weekWorkoutLogs = results[1] as List;
  final measurements = results[2] as List;
  final profile = results[3] as Map<String, dynamic>;

  // This Week counts COMPLETED workout sessions from `workout_logs` — one
  // row per exercise, so a session is a distinct `workout_name` + local
  // date. Verbatim copy of the member Home's math, so the trainer view and
  // the member's own screen always agree.
  final weekCounts = List.generate(7, (i) => 0);
  final completedSessions = <String>{};
  for (final row in weekWorkoutLogs.cast<Map<String, dynamic>>()) {
    final name = (row['workout_name'] as String?)?.trim() ?? '';
    final loggedAt = DateTime.tryParse(row['logged_at'] as String? ?? '');
    if (name.isEmpty || loggedAt == null) continue;
    final sessionKey = '$name|${loggedAt.toLocal()}';
    if (completedSessions.add(sessionKey)) {
      final date = DateTime.parse(sessionKey.split('|')[1]);
      if (date.isAfter(weekStart) && date.isBefore(weekEnd)) {
        weekCounts[date.weekday - 1]++;
      }
    }
  }

  // This Month counts attendance check-ins per month (raw month — the same
  // math the member Home uses for its year chart).
  final monthlyCounts = List.generate(12, (i) => 0);
  for (final a in yearAttendance.cast<Map<String, dynamic>>()) {
    final raw = DateTime.tryParse(a['check_in_time'] as String? ?? '');
    if (raw == null) continue;
    if (raw.month - 1 >= 0 && raw.month - 1 < 12) {
      monthlyCounts[raw.month - 1]++;
    }
  }

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

  return {
    'profile': profile,
    'weekCounts': weekCounts,
    'maxWeek': weekCounts.reduce((a, b) => a > b ? a : b).clamp(1, 100),
    'monthlyCounts': monthlyCounts,
    'monthlyWeights': monthlyBmis,
    'today': today,
  };
});

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

class MemberProgressPage extends ConsumerStatefulWidget {
  final String id;
  const MemberProgressPage({super.key, required this.id});

  @override
  ConsumerState<MemberProgressPage> createState() => _MemberProgressPageState();
}

class _MemberProgressPageState extends ConsumerState<MemberProgressPage> {
  StreamSubscription? _attendanceSub;
  StreamSubscription? _measurementSub;
  StreamSubscription? _workoutSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscribeAttendance();
      _subscribeMeasurements();
      _subscribeWorkoutLogs();
      ref.invalidate(memberProgressDataProvider(widget.id));
    });
  }

  // The charts read workout sessions (This Week), attendance (This Month)
  // and body measurements (Growth), so those are the streams to listen to.
  void _subscribeAttendance() {
    _attendanceSub?.cancel();
    _attendanceSub = SupabaseClientService()
        .client
        .from('attendance')
        .stream(primaryKey: ['id'])
        .eq('member_id', widget.id)
        .order('check_in_time', ascending: false)
        .limit(1)
        .listen((_) => ref.invalidate(memberProgressDataProvider(widget.id)));
  }

  void _subscribeMeasurements() {
    _measurementSub?.cancel();
    _measurementSub = SupabaseClientService()
        .client
        .from('body_measurements')
        .stream(primaryKey: ['id'])
        .eq('member_id', widget.id)
        .order('measured_at', ascending: false)
        .limit(1)
        .listen((_) => ref.invalidate(memberProgressDataProvider(widget.id)));
  }

  void _subscribeWorkoutLogs() {
    _workoutSub?.cancel();
    _workoutSub = SupabaseClientService()
        .client
        .from('workout_logs')
        .stream(primaryKey: ['id'])
        .eq('member_id', widget.id)
        .order('logged_at', ascending: false)
        .limit(1)
        .listen((_) => ref.invalidate(memberProgressDataProvider(widget.id)));
  }

  @override
  void dispose() {
    _attendanceSub?.cancel();
    _measurementSub?.cancel();
    _workoutSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(memberProgressDataProvider(widget.id));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTrainerNavBar('Member Progress'),
              Expanded(
                child: dataAsync.when(
                  data: (data) {
                    final profile = data['profile'] as Map<String, dynamic>;
                    final name = profile['full_name'] as String? ?? 'Member';
                    final email = profile['email'] as String? ?? '';
                    final initials = name.split(' ').map((n) => n[0]).take(2).join();
                    final avatarUrl = profile['avatar_url'] as String?;
                    final weekCounts = data['weekCounts'] as List<int>;
                    final maxWeek = data['maxWeek'] as int;
                    final monthlyCounts = data['monthlyCounts'] as List<int>;
                    final monthlyWeights = data['monthlyWeights'] as List<double?>;

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      physics: const ClampingScrollPhysics(),
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Icon(Icons.chevron_left, color: ClayTokens.clayDarkTextPrimary, size: 22),
                            ),
                            const SizedBox(width: 12),
                            ClayAvatar(
                              imageUrl: avatarUrl,
                              initials: initials,
                              size: ClayAvatarSize.md,
                              backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(30),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: ClayTokens.titleLarge.copyWith(fontWeight: FontWeight.w600, color: ClayTokens.clayDarkTextPrimary, letterSpacing: -0.24)),
                                  if (email.isNotEmpty)
                                    Text(email, style: ClayTokens.bodySmall.copyWith(fontSize: 12, color: ClayTokens.clayDarkTextTertiary, letterSpacing: -0.08)),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () => showCalendarFlipSheet(
                                context,
                                selected: DateTime.now(),
                                today: DateTime.now(),
                                memberId: widget.id,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ActivityStatusBadgeSmall(memberId: widget.id, size: 45),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
                                      ),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      DateFormat('MMM d').format(DateTime.now()),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        _WeekChart(weekCounts: weekCounts, maxCount: maxWeek),
                        const SizedBox(height: 8),
                        _MonthChart(monthlyCounts: monthlyCounts),
                        const SizedBox(height: 8),
                        _GrowthChart(monthlyWeights: monthlyWeights),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                  loading: () => Center(child: CupertinoActivityIndicator(radius: 12, color: ClayTokens.clayPrimary)),
                  error: (e, _) => Center(child: Text('Error: $e', style: ClayTokens.labelMedium.copyWith(fontWeight: FontWeight.w400, color: ClayTokens.clayDarkTextTertiary))),
                ),
              ),
            ],
          ),
        ),
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
              return Expanded(
                child: Text(labels[i],
                  textAlign: TextAlign.center,
                   style: TextStyle(
                     fontSize: 10, fontWeight: FontWeight.w800,
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

class _MonthChart extends StatelessWidget {
  final List<int> monthlyCounts;

  const _MonthChart({required this.monthlyCounts});

  @override
  Widget build(BuildContext context) {
    final current = DateTime.now().month - 1;
    final values = List<double?>.generate(12, (i) {
      if (i > current) return null;
      if (i == current && monthlyCounts[i] == 0) return null;
      return monthlyCounts[i].toDouble();
    });

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
                        DateTime.now().year.toString(),
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
                  'Total: ${monthlyCounts.reduce((a, b) => a + b)}',
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
          ClayAreaChart(
            values: values,
            labels: _monthShort,
            strokeColor: ClayTokens.clayPrimaryDark,
            showYAxis: false,
            showValueLabels: true,
            // Match member Home: purple dot with a matching ring (no halo).
            dotColor: ClayTokens.clayPrimary,
            dotRingColor: ClayTokens.clayPrimaryDark,
          ),
        ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          ClayAreaChart(
            values: monthlyWeights,
            labels: _monthShort,
            strokeColor: ClayTokens.clayPrimaryDark,
            emptyMessage: 'No BMI data yet',
            showValueLabels: true,
            // Match member Home: purple dot with a matching ring (no halo).
            dotColor: ClayTokens.clayPrimary,
            dotRingColor: ClayTokens.clayPrimaryDark,
          ),
        ],
      ),
    );
  }
}

const _monthShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
