import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/app_glow_background.dart';
import '../../../../features/shared/widgets/glass_card.dart';
import '../../../../features/shared/widgets/glass_confirm_dialog.dart';
import '../../../shared/providers/plan_providers.dart';
import '../data/plan_repository.dart';

String _normPlanName(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Containment match so a planned "Bench Press" hits a logged "Bench Press,
/// barbell" (both sides >= 4 chars).
bool _planNameLogged(String name, Set<String> logged) {
  final n = _normPlanName(name);
  if (n.isEmpty) return false;
  if (logged.contains(n)) return true;
  for (final l in logged) {
    if (l.length >= 4 && n.length >= 4 && (l.contains(n) || n.contains(l))) {
      return true;
    }
  }
  return false;
}

/// Buckets the member's logged exercise/food names by the LOCAL calendar day
/// they happened, inside the plan window [startDate, endDate]. Crossing is
/// per-day: Day N only crosses items logged on Day N's date, so two days that
/// both list "Bench Press" no longer cross together.
Future<(Map<String, Set<String>>, Map<String, Set<String>>)>
_fetchCompletedByDay(String memberId, String startDate, String endDate) async {
  try {
    final start = DateTime.parse(startDate).toUtc();
    final end = DateTime.parse(endDate).add(const Duration(days: 1)).toUtc();
    final client = SupabaseClientService().client;
    final workouts = await client
        .from('workout_logs')
        .select('exercise_name, logged_at')
        .eq('member_id', memberId)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String())
        .limit(2000);
    final meals = await client
        .from('meal_logs')
        .select('food_name, meal_time')
        .eq('member_id', memberId)
        .gte('meal_time', start.toIso8601String())
        .lt('meal_time', end.toIso8601String())
        .limit(2000);

    String dayOf(dynamic stamp) => DateTime.parse(
      stamp.toString(),
    ).toLocal().toIso8601String().split('T').first;

    final workoutByDay = <String, Set<String>>{};
    for (final r in workouts as List) {
      final m = r as Map;
      final name = (m['exercise_name'] ?? '').toString();
      if (name.isEmpty) continue;
      workoutByDay
          .putIfAbsent(dayOf(m['logged_at']), () => <String>{})
          .add(_normPlanName(name));
    }
    final foodByDay = <String, Set<String>>{};
    for (final r in meals as List) {
      final m = r as Map;
      final name = (m['food_name'] ?? '').toString();
      if (name.isEmpty) continue;
      foodByDay
          .putIfAbsent(dayOf(m['meal_time']), () => <String>{})
          .add(_normPlanName(name));
    }
    return (workoutByDay, foodByDay);
  } catch (_) {
    return (<String, Set<String>>{}, <String, Set<String>>{});
  }
}

enum _RecordTab { workout, food }

/// Dedicated trainer "record" screen for one member's assigned plan: two tabs
/// (Workout / Foods) over the same per-day grouped plan the trainer built, with
/// per-day completion crossing. Reached by tapping a member on the records list.
class RecordDetailScreen extends ConsumerStatefulWidget {
  final String memberId;
  final String memberName;
  final String? viewTrainerId;
  final String? planId;

  const RecordDetailScreen({
    super.key,
    required this.memberId,
    required this.memberName,
    this.viewTrainerId,
    this.planId,
  });

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  _RecordTab _tab = _RecordTab.workout;
  String? _pendingCancellationPlanId;
  bool _requestingCancellation = false;
  bool _togglingDisplay = false;

  /// Local echo of the display toggle so the button flips as soon as the RPC
  /// succeeds. Reset whenever the loaded plan row changes.
  bool? _displayOverride;
  String? _displayOverridePlanId;
  late Future<Map<String, dynamic>?> _planFuture;
  Future<(Map<String, Set<String>>, Map<String, Set<String>>)>?
  _completionFuture;
  String? _completionKey;

  /// Members open this screen for ONE trainer, so their plan is resolved by
  /// the member/trainer pair. Trainer record routes (no [viewTrainerId]) keep
  /// their previous behaviour of showing the member's current active plan.
  Future<Map<String, dynamic>?> _loadPlan() async {
    final repo = PlanRepository();
    if (widget.planId != null && widget.viewTrainerId == null) {
      return await SupabaseClientService().client
          .from('member_goal_plans')
          .select()
          .eq('id', widget.planId!)
          .eq('member_id', widget.memberId)
          .eq('trainer_id', SupabaseClientService().client.auth.currentUser!.id)
          .maybeSingle();
    }
    final currentUserId = SupabaseClientService().client.auth.currentUser?.id;
    // Member view passes the selected trainer explicitly. Trainer record
    // routes resolve their OWN plan for the member, so two trainers looking
    // at the same member never see each other's plan.
    final trainerId =
        widget.viewTrainerId ??
        (currentUserId != null && currentUserId != widget.memberId
            ? currentUserId
            : null);
    if (trainerId != null && trainerId.isNotEmpty) {
      final plan = await repo.getActivePlan(widget.memberId, trainerId);
      if (plan != null || widget.viewTrainerId != null) return plan;
    }
    // Trainer route with no plan for this pair: fall back to the member's
    // current plan so the older single-plan record view still resolves.
    final plans = await repo.getActivePlans(widget.memberId);
    return plans.isEmpty ? null : plans.first;
  }

  @override
  void initState() {
    super.initState();
    _planFuture = _loadPlan();
    _loadCancellationRequest();
  }

  @override
  void didUpdateWidget(covariant RecordDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId ||
        oldWidget.memberId != widget.memberId ||
        oldWidget.viewTrainerId != widget.viewTrainerId) {
      _planFuture = _loadPlan();
      _displayOverride = null;
      _displayOverridePlanId = null;
      _completionFuture = null;
      _completionKey = null;
      _pendingCancellationPlanId = null;
      _loadCancellationRequest();
    }
  }

  Future<(Map<String, Set<String>>, Map<String, Set<String>>)> _completionFor(
    String startDate,
    String endDate,
  ) {
    final key = '${widget.memberId}|$startDate|$endDate';
    if (_completionKey != key || _completionFuture == null) {
      _completionKey = key;
      _completionFuture = _fetchCompletedByDay(
        widget.memberId,
        startDate,
        endDate,
      );
    }
    return _completionFuture!;
  }

  Future<void> _loadCancellationRequest() async {
    final client = SupabaseClientService().client;
    final memberId = client.auth.currentUser?.id;
    if (memberId == null || memberId != widget.memberId) return;
    try {
      final request = await client
          .from('trainer_plan_cancellation_requests')
          .select('plan_id')
          .eq('member_id', memberId)
          .eq('status', 'pending')
          .limit(1)
          .maybeSingle();
      if (mounted && request != null) {
        setState(
          () => _pendingCancellationPlanId = request['plan_id'] as String?,
        );
      }
    } catch (_) {
      // The plan remains readable if the request migration is not deployed.
    }
  }

  Future<void> _requestPlanCancellation(Map<String, dynamic> plan) async {
    final confirmed = await showGlassConfirmDialog(
      context,
      title: 'Request plan cancellation?',
      message: 'Your trainer will be notified and review your request.',
      keepLabel: 'Keep plan',
      confirmLabel: 'Send request',
    );
    if (confirmed != true || !mounted) return;
    setState(() => _requestingCancellation = true);
    try {
      final client = SupabaseClientService().client;
      final memberId = client.auth.currentUser!.id;
      final trainerId = plan['trainer_id'] as String;
      await client.from('trainer_plan_cancellation_requests').insert({
        'plan_id': plan['id'],
        'member_id': memberId,
        'trainer_id': trainerId,
        'status': 'pending',
      });
      if (!mounted) return;
      setState(() => _pendingCancellationPlanId = plan['id'] as String);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cancellation request sent to your trainer.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send cancellation request: $error')),
      );
    } finally {
      if (mounted) setState(() => _requestingCancellation = false);
    }
  }

  /// Member-only display toggle. Display asks for confirmation (Continue /
  /// Cancel); Remove disables display immediately, exactly like the design.
  Future<void> _togglePlanDisplay(
    Map<String, dynamic> plan,
    bool displayed,
  ) async {
    final planId = plan['id'] as String;
    if (displayed) {
      final confirmed = await showGlassConfirmDialog(
        context,
        title: 'Display this plan?',
        message:
            'It will appear on your Workout and Food Intake screens, where you '
            'can switch between displayed trainer plans.',
        keepLabel: 'Cancel',
        confirmLabel: 'Continue',
        confirmColor: ClayTokens.clayPrimary,
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() => _togglingDisplay = true);
    try {
      await PlanRepository().setPlanDisplayed(planId, displayed);
      if (!mounted) return;
      setState(() {
        _displayOverride = displayed;
        _displayOverridePlanId = planId;
      });
      // Workout / Food Intake read the displayed set and the shared selection
      // from these providers, so both surfaces refresh together.
      ref.invalidate(displayedPlansProvider);
      ref.invalidate(hasDisplayedPlanProvider);
      ref.invalidate(selectedDisplayedPlanProvider);
      ref.invalidate(activePlansProvider);
      final selection = ref.read(selectedPlanIdProvider.notifier);
      if (displayed) {
        await selection.select(planId);
      } else if (ref.read(selectedPlanIdProvider) == planId) {
        await selection.select(null);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            displayed
                ? 'Plan displayed on Workout and Food Intake.'
                : 'Plan removed from Workout and Food Intake.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update this plan: $error')),
      );
    } finally {
      if (mounted) setState(() => _togglingDisplay = false);
    }
  }

  Widget _displayControl(Map<String, dynamic> plan) {
    final planId = plan['id'] as String;
    final displayed = _displayOverridePlanId == planId
        ? (_displayOverride ?? plan['is_displayed'] == true)
        : plan['is_displayed'] == true;
    // Purple button: white label in dark mode, dark label in light mode.
    final onPurple = ClayColors.isLightMode
        ? ClayTokens.clayDarkSurface
        : Colors.white;
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(
            displayed ? Icons.visibility : Icons.visibility_off,
            size: 18,
            color: displayed
                ? ClayTokens.clayPrimary
                : ClayTokens.clayDarkTextTertiary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Workout & Food Intake',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  displayed
                      ? 'This plan is displayed. Remove it to hide it there.'
                      : 'Display this plan to use it on those screens.',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF8E8E93),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: displayed
                ? ClayTokens.hairline.withAlpha(30)
                : ClayTokens.clayPrimary,
            disabledColor: ClayTokens.clayPrimary.withAlpha(80),
            onPressed: _togglingDisplay
                ? null
                : () => _togglePlanDisplay(plan, !displayed),
            child: _togglingDisplay
                ? CupertinoActivityIndicator(color: onPurple, radius: 8)
                : Text(
                    displayed ? 'Remove' : 'Display',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: displayed
                          ? ClayTokens.clayDarkTextPrimary
                          : onPurple,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayColors.isLightMode
          ? ClayTokens.claySurfaceLight.withAlpha(250)
          : ClayTokens.clayDarkSurface,
      body: AppGlowBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: _planFuture,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)),
                );
              }
              final plan = snap.data;
              if (plan == null) {
                // Members viewing their own Trainer Plan get the friendly
                // "no active plan" placeholder; trainers opening a member's
                // record keep the plain empty-state message.
                final isSelfView =
                    SupabaseClientService().client.auth.currentUser?.id ==
                    widget.memberId;
                return Column(
                  children: [
                    _buildHeader(days: 0, total: 7),
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isSelfView
                                  ? CupertinoIcons.calendar_badge_minus
                                  : CupertinoIcons.doc_text,
                              size: 40,
                              color: const Color(0xFF8E8E93),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isSelfView
                                  ? 'No active plan'
                                  : 'No plan assigned yet',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              final startDate = plan['start_date'] as String? ?? '';
              final endDate = plan['end_date'] as String? ?? '';
              final foodPlan =
                  (plan['food_plan'] as List<dynamic>?) ?? const [];
              final exercisePlan =
                  (plan['exercise_plan'] as List<dynamic>?) ?? const [];

              return FutureBuilder<
                (Map<String, Set<String>>, Map<String, Set<String>>)
              >(
                future: _completionFor(startDate, endDate),
                builder: (context, doneSnap) {
                  final workoutByDay =
                      doneSnap.data?.$1 ?? const <String, Set<String>>{};
                  final foodByDay =
                      doneSnap.data?.$2 ?? const <String, Set<String>>{};
                  final base = _safeParse(startDate);

                  final workoutSections = _buildSections(
                    exercisePlan,
                    'exercises',
                    base,
                    (row, dayKey) =>
                        _exerciseItem(row, workoutByDay[dayKey] ?? const {}),
                  );
                  final foodSections = _buildSections(foodPlan, 'foods', base, (
                    row,
                    dayKey,
                  ) {
                    final name = (row['name'] ?? '').toString();
                    return (
                      text: name,
                      done:
                          name.isNotEmpty &&
                          _planNameLogged(name, foodByDay[dayKey] ?? const {}),
                    );
                  });

                  final sections = _tab == _RecordTab.workout
                      ? workoutSections
                      : foodSections;
                  final doneCount = sections.fold<int>(
                    0,
                    (s, x) => s + x.items.where((i) => i.done).length,
                  );

                  return Column(
                    children: [
                      _buildHeader(days: doneCount, total: sections.length),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          layoutBuilder: (currentChild, previousChildren) =>
                              Stack(
                                alignment: Alignment.topCenter,
                                children: [
                                  ...previousChildren,
                                  if (currentChild != null) currentChild,
                                ],
                              ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0.025, 0),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: SingleChildScrollView(
                            key: ValueKey(_tab),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _tabPill(),
                                const SizedBox(height: 12),
                                Text(
                                  'Schedule: $startDate — $endDate',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF8E8E93),
                                  ),
                                ),
                                if (SupabaseClientService()
                                        .client
                                        .auth
                                        .currentUser
                                        ?.id ==
                                    widget.memberId) ...[
                                  const SizedBox(height: 12),
                                  _displayControl(plan),
                                  const SizedBox(height: 10),
                                  GlassPanel(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _pendingCancellationPlanId ==
                                                    plan['id']
                                                ? 'Cancellation request sent. Your plan stays active until reviewed.'
                                                : 'Need to stop this plan? Request cancellation from your trainer.',
                                            style: TextStyle(
                                              color: ClayTokens
                                                  .clayDarkTextPrimary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (_pendingCancellationPlanId !=
                                            plan['id'])
                                          CupertinoButton(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            color: const Color(0xFFDC2626),
                                            onPressed: _requestingCancellation
                                                ? null
                                                : () =>
                                                      _requestPlanCancellation(
                                                        plan,
                                                      ),
                                            child: _requestingCancellation
                                                ? CupertinoActivityIndicator(
                                                    color: ClayTokens
                                                        .clayDarkTextPrimary,
                                                  )
                                                : Text(
                                                    'Request',
                                                    style: TextStyle(
                                                      color: ClayTokens
                                                          .clayDarkTextPrimary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                if (sections.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 24),
                                    child: Center(
                                      child: Text(
                                        _tab == _RecordTab.workout
                                            ? 'No exercises planned'
                                            : 'No meals planned',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  for (final s in sections)
                                    _PlanDaySection(
                                      day: s.day,
                                      title: s.title,
                                      items: s.items,
                                      notes: s.notes,
                                    ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _tabPill() {
    return Container(
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: ClayTokens.hairline.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ClayTokens.hairline.withAlpha(20)),
      ),
      child: Row(
        children: [
          _tabChip('Workout', _RecordTab.workout),
          _tabChip('Foods', _RecordTab.food),
        ],
      ),
    );
  }

  Widget _tabChip(String label, _RecordTab value) {
    final active = _tab == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                  )
                : null,
            color: active ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : const Color(0xFF8E8E93),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({required int days, required int total}) {
    // Members see this screen per trainer, so the subtitle names the screen
    // rather than the trainer-facing "Records".
    final isSelfView =
        SupabaseClientService().client.auth.currentUser?.id == widget.memberId;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.memberName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.clayDarkTextPrimary,
                    decoration: TextDecoration.none,
                  ),
                ),
                Text(
                  isSelfView ? 'Trainer Plan' : 'Records',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8E8E93),
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: ClayTokens.clayPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$days done',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ClayTokens.clayPrimaryLight,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  DateTime? _safeParse(String s) {
    try {
      return DateTime.parse(s);
    } catch (_) {
      return null;
    }
  }

  /// Groups a per-day plan column (`[{day, exercises|foods: [...]}, ...]`) into
  /// day sections. `doneFor` computes each row's done state from that day's
  /// bucketed log set (per-day crossing). Tolerates a legacy flat shape.
  List<_SectionData> _buildSections(
    List<dynamic> planColumn,
    String nestedKey,
    DateTime? base,
    ({String text, bool done}) Function(Map, String) doneFor,
  ) {
    final byDayNum = <int, List<Map>>{};
    final notesByDay = <int, String>{};
    for (final group in planColumn) {
      if (group is! Map) continue;
      final dayNum = group['day'];
      if (dayNum is! int) continue;
      final notes = group['notes']?.toString().trim() ?? '';
      if (notes.isNotEmpty) notesByDay[dayNum] = notes;
      final nested = group[nestedKey];
      final rows = <Map>[];
      if (nested is List) {
        rows.addAll(nested.whereType<Map>());
      } else if ((group['name'] as String?)?.isNotEmpty == true) {
        rows.add(group);
      }
      byDayNum.putIfAbsent(dayNum, () => <Map>[]).addAll(rows);
    }
    final keys = byDayNum.keys.toList()..sort();
    final sections = <_SectionData>[];
    for (final dayNum in keys) {
      final rows = byDayNum[dayNum]!;
      final dayKey = base == null ? '' : _dayKeyFor(base, dayNum);
      final items = <({String text, bool done})>[];
      for (final row in rows) {
        final item = doneFor(Map<String, dynamic>.from(row), dayKey);
        if (item.text.trim().isNotEmpty) items.add(item);
      }
      if (items.isEmpty) continue;
      sections.add(
        _SectionData(
          day: dayNum,
          title: nestedKey == 'foods' ? 'Meals' : 'Exercises',
          items: items,
          notes: notesByDay[dayNum] ?? '',
        ),
      );
    }
    return sections;
  }

  String _dayKeyFor(DateTime base, int dayNum) {
    final d = DateTime(
      base.year,
      base.month,
      base.day,
    ).add(Duration(days: dayNum - 1));
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _SectionData {
  final int day;
  final String title;
  final List<({String text, bool done})> items;
  final String notes;
  _SectionData({
    required this.day,
    required this.title,
    required this.items,
    this.notes = '',
  });
}

({String text, bool done}) _exerciseItem(Map m, Set<String> workoutNames) {
  final name = (m['name'] ?? '').toString();
  final sets = (m['sets'] ?? '').toString();
  final reps = (m['reps'] ?? '').toString();
  final weight = (m['weight'] ?? '').toString();
  final detail = [
    if (sets.isNotEmpty) '$sets sets',
    if (reps.isNotEmpty) '$reps reps',
    if (weight.isNotEmpty) '${weight}kg',
  ].join(' · ');
  return (
    text: detail.isEmpty ? name : '$name — $detail',
    done: _planNameLogged(name, workoutNames),
  );
}

/// One day's block ("Day 1 · Exercises" / "Day 1 · Meals"). Items the member
/// logged on that specific day render crossed out with a green check.
class _PlanDaySection extends StatelessWidget {
  final int day;
  final String title;
  final List<({String text, bool done})> items;
  final String notes;

  const _PlanDaySection({
    required this.day,
    required this.title,
    required this.items,
    required this.notes,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = items.where((i) => i.done).length;
    final allDone = items.isNotEmpty && doneCount == items.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassPanel(
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $day · $title',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                Text(
                  '$doneCount/${items.length} ${allDone ? "Complete" : "In Complete"}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: allDone
                        ? const Color(0xFF30D158)
                        : const Color(0xFFFF9F0A),
                  ),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Notes: $notes',
                style: TextStyle(
                  fontSize: 12,
                  color: ClayTokens.clayDarkTextPrimary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      item.done
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 13,
                      color: item.done
                          ? const Color(0xFF30D158)
                          : const Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: item.done
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: item.done
                              ? const Color(0xFF8E8E93)
                              : ClayTokens.clayDarkTextPrimary,
                        ),
                      ),
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
