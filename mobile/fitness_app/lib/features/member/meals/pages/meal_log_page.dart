import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared/services/supabase_client.dart';

import '../../../shared/widgets/pressable.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/app_glow_background.dart';
import '../../../shared/widgets/plan_floating_logo.dart';
import '../../../shared/providers/plan_providers.dart';
import '../../../shared/utils/plan_day.dart';
import '../../../shared/widgets/trainer_plan_overlay.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../calendar/providers/month_entries_provider.dart';
import '../../calendar/widgets/month_day_grid.dart';
import '../../calendar/widgets/flip_card.dart';
import '../../calendar/widgets/light_aware_glow_card.dart';

import 'add_food_wizard.dart';
import '../../goals/providers/food_goal_provider.dart';

/// Member Food Intake screen: today's macro ring + logged meals. Adding a meal
/// opens the photo -> meal type -> FNRI search -> grams -> review wizard
/// (see docs/superpowers/specs/2026-09-25-food-intake-philfct-wizard-design.md).
final mealsForDateProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, DateTime)>((
      ref,
      params,
    ) async {
      final userId = params.$1;
      final day = params.$2;
      final startOfDay = DateTime(day.year, day.month, day.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      final response = await SupabaseClientService().client
          .from('meal_logs')
          .select()
          .eq('member_id', userId)
          .gte('meal_time', startOfDay.toUtc().toIso8601String())
          .lt('meal_time', endOfDay.toUtc().toIso8601String())
          .order('meal_time', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    });

final mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
const mealIcons = {
  'breakfast': CupertinoIcons.sun_max,
  'lunch': CupertinoIcons.sun_max,
  'dinner': CupertinoIcons.moon,
  'snack': CupertinoIcons.info,
};
const mealIconColors = {
  'breakfast': Color(0xFFFF9500),
  'lunch': Color(0xFF0A84FF),
  'dinner': Color(0xFF7C3AED),
  'snack': Color(0xFF30D158),
};

/// Opens the trainer's plan sheet for the floating logo, showing the day
/// that is active TODAY: Day 1 on the plan's start date, Day 2 once one
/// calendar day (24 h) has passed, and so on up to the plan's last day.
///
/// `activePlanProvider` is `autoDispose`, so `ref.read(...)` on a provider
/// nobody is watching hands back an unresolved `AsyncValue` whose `.value`
/// is null — the old code returned right there, which is why tapping the
/// logo did nothing at all. Awaiting `.future` loads it on demand.
Future<void> _openActivePlanSheet(BuildContext context, WidgetRef ref) async {
  final overlay = ref.read(planOverlayControllerProvider);
  if (overlay.isOpen) {
    overlay.close();
    return;
  }

  final plan = await ref.read(activePlanProvider.future);
  if (plan == null || !context.mounted) return;

  overlay.openForFood(
    SupabaseClientService().client.auth.currentUser!.id,
    plan['start_date'] as String? ?? '',
    totalDays: planDayCount(plan['food_plan']),
  );
  final dayNumber = overlay.currentDay;
  showModalBottomSheet(
    context: context,
    // Root navigator: the sheet (and its scrim) covers the shell's bottom
    // nav bar — otherwise the branch-level sheet renders UNDER the bar and
    // the nav stays visible on top of the plan overlay.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TrainerPlanFoodOverlay(
      planId: plan['id'] as String,
      dayNumber: dayNumber,
      notes: plan['notes'] as String?,
    ),
  ).then((_) {
    if (overlay.isOpen) overlay.close();
  });
}

class MealLogPage extends ConsumerStatefulWidget {
  const MealLogPage({super.key});

  @override
  ConsumerState<MealLogPage> createState() => _MealLogPageState();
}

class _MealLogPageState extends ConsumerState<MealLogPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Future<void> _openCalendar(String memberId) async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Align(
        alignment: const Alignment(0, 0.15),
        child: _FoodHistoryCalendar(
          selected: _selectedDate,
          memberId: memberId,
        ),
      ),
    );
    // Do not let calendar picks change the main screen's date: the member's
    // Food Intake screen always shows today unless they explicitly navigate
    // elsewhere. The calendar modal is a read-only historical viewer.
    if (picked != null && mounted) {
      // Keep _selectedDate on today; calendar picks stay inside the modal.
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberId = SupabaseClientService().client.auth.currentUser!.id;
    final mealsAsync = ref.watch(
      mealsForDateProvider((memberId, _selectedDate)),
    );
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AppGlowBackground(
        child: SafeArea(
          // LayoutBuilder must wrap the Stack, not sit inside it: `Positioned`
          // is a ParentDataWidget that only works as a DIRECT child of a
          // Stack (wrapping it throws "Incorrect use of ParentDataWidget").
          // The constraints here are exactly the body box, which Scaffold
          // already sized without the bottom nav bar — so clamping to them
          // makes it impossible to drag the logo underneath the nav bar.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bounds = Size(constraints.maxWidth, constraints.maxHeight);
              return Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    physics: const ClampingScrollPhysics(),
                    children: [
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'FOOD INTAKE',
                            style: TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: ClayTokens.clayDarkTextPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7C3AED).withAlpha(140),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withAlpha(180),
                                  ),
                                ),
                                child: mealsAsync.when(
                                  data: (meals) => Text(
                                    '${meals.length} meal${meals.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  loading: () => Text(
                                    '...',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  error: (_, __) => Text(
                                    '0 meals',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _openCalendar(memberId),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF7C3AED,
                                    ).withAlpha(140),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7C3AED,
                                      ).withAlpha(180),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat(
                                          'MMM d',
                                        ).format(_selectedDate),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      mealsAsync.when(
                        data: (meals) =>
                            _TodayMacroRing(meals: meals, date: _selectedDate),
                        loading: () => _TodayMacroRing(
                          meals: const [],
                          date: _selectedDate,
                        ),
                        error: (_, __) => _TodayMacroRing(
                          meals: const [],
                          date: _selectedDate,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        _selectedDate.year == DateTime.now().year &&
                                _selectedDate.month == DateTime.now().month &&
                                _selectedDate.day == DateTime.now().day
                            ? 'MEALS TODAY'
                            : 'MEALS ON ${DateFormat('MMM d').format(_selectedDate).toUpperCase()}',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF8E8E93),
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 9),
                      mealsAsync.when(
                        data: (meals) => Column(
                          children: [
                            ...meals.asMap().entries.map(
                              (entry) => StaggeredFadeIn(
                                index: entry.key,
                                child: _MealCard(meal: entry.value),
                              ),
                            ),
                            if (meals.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 24),
                                child: Text(
                                  'No meals logged for this date',
                                  style: TextStyle(
                                    color: Color(0xFF636366),
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        loading: () => const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(
                              color: Color(0xFFD6A5FF),
                            ),
                          ),
                        ),
                        error: (e, _) => Text(
                          'Error: $e',
                          style: const TextStyle(color: Color(0xFF636366)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _addFoodButton(context, ref),
                      const SizedBox(height: 16),
                    ],
                  ),
                  // No Positioned.fill wrapper: it would swallow touches over
                  // the whole screen. The logo positions itself, so only its
                  // own pixels hit-test — drags start on the logo directly.
                  Consumer(
                    builder: (context, ref, _) {
                      if (!(ref.watch(hasActivePlanProvider).value ?? false)) {
                        return const SizedBox.shrink();
                      }
                      final logoPos = ref.watch(floatingLogoPositionProvider);
                      final f = logoPos.clampedFraction(bounds);
                      return Positioned(
                        left: f.dx * bounds.width,
                        top: f.dy * bounds.height,
                        child: PlanFloatingLogo(
                          memberId: SupabaseClientService()
                              .client
                              .auth
                              .currentUser!
                              .id,
                          isExpanded: ref
                              .watch(planOverlayControllerProvider)
                              .isOpen,
                          bounds: bounds,
                          withGlass: false,
                          onTap: () => _openActivePlanSheet(context, ref),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _addFoodButton(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(
          context,
          rootNavigator: true,
        ).push(MaterialPageRoute(builder: (_) => const AddFoodWizard()));
        ref.invalidate(
          mealsForDateProvider((
            SupabaseClientService().client.auth.currentUser!.id,
            _selectedDate,
          )),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED),
          borderRadius: BorderRadius.circular(14),
        ),
        // Text only — the old "+" icon is gone, per the design pass.
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Add Food',
              style: TextStyle(
                color: ClayTokens.clayDarkTextPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodHistoryCalendar extends ConsumerStatefulWidget {
  final DateTime selected;
  final String memberId;

  const _FoodHistoryCalendar({required this.selected, required this.memberId});

  @override
  ConsumerState<_FoodHistoryCalendar> createState() =>
      _FoodHistoryCalendarState();
}

class _FoodHistoryCalendarState extends ConsumerState<_FoodHistoryCalendar> {
  late DateTime _selected;
  late DateTime _month;
  bool _flipped = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
    _month = DateTime(_selected.year, _selected.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref
        .watch(monthEntriesProvider((widget.memberId, _month)))
        .valueOrNull;
    final meals = entries == null
        ? <Map<String, dynamic>>[]
        : (entries['meals'] as List).cast<Map<String, dynamic>>();
    final today = DateTime.now();
    return SafeArea(
      child: Container(
        height: 500,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: ClayColors.isLightMode
              ? ClayTokens.claySurfaceLight.withAlpha(245)
              : ClayTokens.clayDarkSurface.withAlpha(245),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: ClayColors.isLightMode
                ? ClayTokens.clayPrimary.withAlpha(45)
                : ClayTokens.hairline.withAlpha(25)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'CALENDAR FOOD INTAKE',
                    style: TextStyle(
                      color: ClayTokens.clayDarkTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, _selected),
                  icon: Icon(
                    Icons.close,
                    color: ClayTokens.clayDarkTextSecondary,
                    size: 18,
                  ),
                ),
              ],
            ),
            Expanded(
              // LightAwareGlowCard: light mode gets the same light clay panel
              // as the workout calendar; dark mode keeps the dark GlowCard.
              child: LightAwareGlowCard(
                borderRadius: 16,
                borderWidth: 1.6,
                child: FlipCard(
                  flipped: _flipped,
                  front: Column(
                    children: [
                      Expanded(
                        child: MonthDayGrid(
                          visibleMonth: _month,
                          selected: _selected,
                          today: today,
                          workouts: const [],
                          meals: meals,
                          showWorkoutIndicators: false,
                          showGoalIndicators: false,
                          onDayTap: (day) => setState(() => _selected = day),
                          onShiftMonth: (delta) => setState(
                            () => _month = DateTime(
                              _month.year,
                              _month.month + delta,
                              1,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: _FoodHistoryButton(
                          label: 'View Meals',
                          onPressed: () => setState(() => _flipped = true),
                        ),
                      ),
                    ],
                  ),
                  back: _FoodHistoryBack(
                    memberId: widget.memberId,
                    date: _selected,
                    onFlip: () => setState(() => _flipped = false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FoodHistoryBack extends ConsumerWidget {
  final String memberId;
  final DateTime date;
  final VoidCallback onFlip;

  const _FoodHistoryBack({
    required this.memberId,
    required this.date,
    required this.onFlip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(mealsForDateProvider((memberId, date)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Text(
            DateFormat('EEEE, MMM d').format(date),
            style: TextStyle(
              color: ClayTokens.clayDarkTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: mealsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Color(0xFFA78BFA)),
            ),
            error: (_, __) => Center(
              child: Text(
                'Could not load meals for this date.',
                style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
              ),
            ),
            data: (meals) => meals.isEmpty
                ? Center(
                    child: Text(
                      'No meals recorded for this date.',
                      style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: meals.length,
                    itemBuilder: (context, index) {
                      final meal = meals[index];
                      final name = meal['food_name'] as String? ?? 'Food';
                      final type = meal['meal_type'] as String? ?? 'Meal';
                      final calories = meal['calories'] as int? ?? 0;
                      final protein = meal['protein_g'] ?? 0;
                      final carbs = meal['carbs_g'] ?? 0;
                      final fat = meal['fat_g'] ?? 0;
                      return Container(
                        margin: EdgeInsets.only(bottom: 8),
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ClayTokens.hairline.withAlpha(10),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ClayTokens.hairline.withAlpha(18)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      color: ClayTokens.clayDarkTextPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$calories kcal',
                                  style: const TextStyle(
                                    color: Color(0xFFD6A5FF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${type[0].toUpperCase()}${type.substring(1)} ? ${DateFormat('h:mm a').format(DateTime.tryParse(meal['meal_time'] as String? ?? '')?.toLocal() ?? date)}',
                              style: TextStyle(
                                color: ClayTokens.clayDarkTextSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'Protein ${protein}g   Carbs ${carbs}g   Fat ${fat}g',
                              style: const TextStyle(
                                color: Color(0xFFCEB9EE),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _FoodHistoryButton(
            label: 'Back to Calendar',
            onPressed: onFlip,
          ),
        ),
      ],
    );
  }
}

class _FoodHistoryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _FoodHistoryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(foregroundColor: Colors.white),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class _TodayMacroRing extends ConsumerWidget {
  final List<Map<String, dynamic>> meals;
  final DateTime date;

  const _TodayMacroRing({required this.meals, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalCal = meals.fold(
      0,
      (sum, m) => sum + (m['calories'] as int? ?? 0),
    );
    final totalProt = meals.fold(
      0.0,
      (sum, m) => sum + (m['protein_g'] as double? ?? 0.0),
    );
    final totalCarb = meals.fold(
      0.0,
      (sum, m) => sum + (m['carbs_g'] as double? ?? 0.0),
    );
    final totalFat = meals.fold(
      0.0,
      (sum, m) => sum + (m['fat_g'] as double? ?? 0.0),
    );

    // Running food goal (if any): drive a small "goal / left / over" hint under
    // the ring so the daily calorie target is visible while logging. Only shown
    // for today (the ring is a per-day read); other days keep the plain label.
    final foodGoal = ref.watch(activeFoodGoalProvider).valueOrNull;
    final isToday =
        date.year == DateTime.now().year &&
        date.month == DateTime.now().month &&
        date.day == DateTime.now().day;
    final dailyTarget = (foodGoal?['target_value'] as num?)?.toDouble();
    final hasGoal = isToday && dailyTarget != null && dailyTarget > 0;
    final goalLeft = hasGoal ? (dailyTarget - totalCal).round() : 0;
    final goalHint = hasGoal
        ? (goalLeft >= 0
              ? '${dailyTarget.toStringAsFixed(0)} kcal goal · $goalLeft left'
              : '${dailyTarget.toStringAsFixed(0)} kcal goal · ${-goalLeft} over')
        : null;
    final goalOver = hasGoal && goalLeft < 0;

    final protCal = totalProt * 4;
    final carbCal = totalCarb * 4;
    final fatCal = totalFat * 9;
    final macroTotal = protCal + carbCal + fatCal;

    final protPct = macroTotal > 0 ? protCal / macroTotal : 0.0;
    final carbPct = macroTotal > 0 ? carbCal / macroTotal : 0.0;
    final fatPct = macroTotal > 0 ? fatCal / macroTotal : 0.0;

    // With no macros logged every fraction is 0, which the pie cannot render,
    // so show a single muted track instead.
    final ringSections = macroTotal > 0
        ? <PieChartSectionData>[
            PieChartSectionData(
              value: protPct,
              color: const Color(0xFF0A84FF),
              radius: 20,
              // fl_chart defaults to painting `value.toString()` inside each
              // slice — that is what printed the raw fractions (0.30623…) on
              // the ring.
              showTitle: false,
            ),
            PieChartSectionData(
              value: carbPct,
              color: const Color(0xFFFF9500),
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: fatPct,
              color: const Color(0xFF30D158),
              radius: 20,
              showTitle: false,
            ),
          ]
        : <PieChartSectionData>[
            PieChartSectionData(
              value: 1,
              color: glassRimSoft(const Color(0x1FFFFFFF)),
              radius: 20,
              showTitle: false,
            ),
          ];

    return MemberGlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(20),
      // Dark mode keeps its exact translucent panel.
      darkBuilder: (cardChild) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0x12FFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x2EFFFFFF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: cardChild,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 30,
                    startDegreeOffset: -90,
                    sections: ringSections,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$totalCal',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: ClayColors.isLightMode
                            ? ClayTokens.clayDarkTextPrimary
                            : Colors.white,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ClayTokens.clayDarkTextSecondary,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'consumed',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: ClayTokens.clayDarkTextTertiary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day ? 'Daily' : DateFormat('MMM d').format(date)} Intake',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  macroTotal > 0
                      ? '$totalCal kcal · ${meals.length} meal${meals.length == 1 ? '' : 's'}'
                      : 'Nothing logged yet',
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
                if (goalHint != null) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        goalOver
                            ? CupertinoIcons.exclamationmark_circle_fill
                            : CupertinoIcons.flame_fill,
                        size: 11,
                        color: goalOver
                            ? const Color(0xFFFBBF24)
                            : ClayTokens.clayPrimary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        goalHint,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: goalOver
                              ? const Color(0xFFFBBF24)
                              : ClayTokens.clayPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                _MacroMiniCard(
                  label: 'Protein',
                  grams: totalProt,
                  pct: protPct,
                  color: const Color(0xFF0A84FF),
                ),
                const SizedBox(height: 6),
                _MacroMiniCard(
                  label: 'Carbs',
                  grams: totalCarb,
                  pct: carbPct,
                  color: const Color(0xFFFF9500),
                ),
                const SizedBox(height: 6),
                _MacroMiniCard(
                  label: 'Fat',
                  grams: totalFat,
                  pct: fatPct,
                  color: const Color(0xFF30D158),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroMiniCard extends StatelessWidget {
  final String label;
  final double grams;
  final double pct;
  final Color color;

  const _MacroMiniCard({
    required this.label,
    required this.grams,
    required this.pct,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pctStr = pct > 0 ? '${(pct * 100).toStringAsFixed(0)}%' : '0%';
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 40,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextPrimary,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 4,
                decoration: BoxDecoration(
                  color: glassRimSoft(const Color(0xFF2C2C2E)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              FractionallySizedBox(
                widthFactor: pct.clamp(0.0, 1.0),
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(
            '${grams.toStringAsFixed(0)}g · $pctStr',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  final Map<String, dynamic> meal;

  const _MealCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final type = meal['meal_type'] as String? ?? 'snack';
    final name = meal['food_name'] as String? ?? '';
    final calories = meal['calories'] as int?;
    final protein = meal['protein_g'] as double?;
    final carbs = meal['carbs_g'] as double?;
    final fat = meal['fat_g'] as double?;
    final photoUrl = meal['photo_url'] as String?;
    final icon = mealIcons[type] ?? CupertinoIcons.info;
    final iconColor = mealIconColors[type] ?? const Color(0xFF30D158);

    return Semantics(
      label: '$name, $type${calories != null ? ', $calories calories' : ''}',
      child: PressableCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        margin: const EdgeInsets.only(bottom: 7),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _placeholderIcon(icon, iconColor),
                    )
                  : _placeholderIcon(icon, iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ClayTokens.clayDarkTextPrimary,
                    ),
                  ),
                  Text(
                    type[0].toUpperCase() + type.substring(1),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF8E8E93),
                    ),
                  ),
                ],
              ),
            ),
            if (calories != null)
              Text(
                '$calories kcal',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFD6A5FF),
                ),
              ),
            const SizedBox(width: 8),
            Wrap(
              spacing: 4,
              children: [
                if (protein != null)
                  _MacroPill(
                    label: 'P',
                    value: protein,
                    color: const Color(0xFF0A84FF),
                  ),
                if (carbs != null)
                  _MacroPill(
                    label: 'C',
                    value: carbs,
                    color: const Color(0xFFFF9500),
                  ),
                if (fat != null)
                  _MacroPill(
                    label: 'F',
                    value: fat,
                    color: const Color(0xFF30D158),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderIcon(IconData icon, Color color) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label ${value.toStringAsFixed(0)}g',
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
