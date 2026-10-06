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
import '../../../shared/widgets/trainer_plan_overlay.dart';
import '../../../../app/design_tokens.dart';

import 'add_food_wizard.dart';

/// Member Food Intake screen: today's macro ring + logged meals. Adding a meal
/// opens the photo -> meal type -> FNRI search -> grams -> review wizard
/// (see docs/superpowers/specs/2026-09-25-food-intake-philfct-wizard-design.md).
final todayMealsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final userId = SupabaseClientService().client.auth.currentUser!.id;
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
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
  'dinner': Color(0xFFBF5AF2),
  'snack': Color(0xFF30D158),
};

class MealLogPage extends ConsumerWidget {
  const MealLogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(todayMealsProvider);
    final hasPlan = ref.watch(hasActivePlanProvider).value ?? false;
    final overlay = ref.watch(planOverlayControllerProvider);
    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                physics: const ClampingScrollPhysics(),
                children: [
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'FOOD INTAKE',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFFFFFFF),
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
                              color: const Color(0xFFBF5AF2).withAlpha(140),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFBF5AF2).withAlpha(180),
                              ),
                            ),
                            child: Text(
                              DateFormat('MMM d').format(DateTime.now()),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFBF5AF2).withAlpha(140),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFBF5AF2).withAlpha(180),
                              ),
                            ),
                            child: mealsAsync.when(
                              data: (meals) => Text(
                                '${meals.length} meal${meals.length == 1 ? '' : 's'}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                              loading: () => const Text(
                                '...',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                              error: (_, __) => const Text(
                                '0 meals',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFFFFFFF),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  mealsAsync.when(
                    data: (meals) => _TodayMacroRing(meals: meals),
                    loading: () => const _TodayMacroRing(meals: []),
                    error: (_, __) => const _TodayMacroRing(meals: []),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'MEALS TODAY',
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
                              'No meals logged today',
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
              if (hasPlan)
                Positioned(
                  right: 16,
                  bottom: 96,
                  child: PlanFloatingLogo(
                    memberId:
                        SupabaseClientService().client.auth.currentUser!.id,
                    isExpanded: overlay.isOpen,
                    onTap: () {
                      final planAsync = ref.read(activePlanProvider);
                      final plan = planAsync.value;
                      if (plan == null) return;

                      if (overlay.isOpen) {
                        overlay.close();
                      } else {
                        overlay.openForFood(
                          SupabaseClientService().client.auth.currentUser!.id,
                          plan['start_date'] as String? ?? '',
                        );
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => TrainerPlanFoodOverlay(
                            planId: plan['id'] as String,
                            dayNumber: overlay.currentDay,
                            notes: plan['notes'] as String?,
                          ),
                        ).then((_) {
                          if (overlay.isOpen) overlay.close();
                        });
                      }
                    },
                  ),
                ),
            ],
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
        ref.invalidate(todayMealsProvider);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFBF5AF2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.add, color: Colors.white, size: 17),
            SizedBox(width: 6),
            Text(
              'Add Food',
              style: TextStyle(
                color: Colors.white,
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

class _TodayMacroRing extends ConsumerWidget {
  final List<Map<String, dynamic>> meals;

  const _TodayMacroRing({required this.meals});

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
              color: const Color(0x1FFFFFFF),
              radius: 20,
              showTitle: false,
            ),
          ];

    return Container(
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
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFFFFF),
                        height: 1.05,
                      ),
                    ),
                    const Text(
                      'kcal',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFFFFFFF),
                        height: 1.2,
                      ),
                    ),
                    const Text(
                      'consumed',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFFFFFFF),
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
                const Text(
                  'Daily Intake',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  macroTotal > 0
                      ? '$totalCal kcal · ${meals.length} meal${meals.length == 1 ? '' : 's'}'
                      : 'Nothing logged yet',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFFFFFF),
                  ),
                ),
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
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
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
                  color: const Color(0xFF2C2C2E),
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
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFFFFFFFF),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFFFFF),
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
