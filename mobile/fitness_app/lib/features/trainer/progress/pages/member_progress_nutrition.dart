import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../progress/widgets/member_tab_widgets.dart';
import '../../progress/providers/member_tab_providers.dart';

/// Nutrition tab of Member Progress: a macro donut (protein / carbs / fat by
/// calorie share) that re-sums whenever the date window changes, plus the
/// meal list (10 per page) with a photo viewer for meals that have one.
class NutritionTab extends ConsumerStatefulWidget {
  final String id;
  const NutritionTab({super.key, required this.id});

  @override
  ConsumerState<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends ConsumerState<NutritionTab> {
  static const _pageSize = 10;

  String _preset = 'month';
  late DateTime _start;
  late DateTime _end;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _applyPreset('month');
  }

  void _applyPreset(String preset) {
    final w = presetWindow(preset, DateTime.now());
    setState(() {
      _preset = preset;
      _start = w.start;
      _end = w.end;
      _page = 0;
    });
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _start : _end,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: ClayTokens.clayPrimary,
            onPrimary: Colors.white,
            surface: ClayTokens.clayDarkSurfaceElevated,
            onSurface: ClayTokens.clayDarkTextPrimary,
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide.none,
            ),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF14142A).withAlpha(175),
                    const Color(0xFF221A4A).withAlpha(145),
                    const Color(0xFF14142A).withAlpha(185),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withAlpha(38)),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final day = DateTime(picked.year, picked.month, picked.day);
    final dayEnd = DateTime(picked.year, picked.month, picked.day, 23, 59, 59, 999);
    setState(() {
      _preset = 'custom';
      if (isStart) {
        _start = day;
        if (_end.isBefore(_start)) _end = dayEnd;
      } else {
        _end = dayEnd;
        if (_start.isAfter(_end)) _start = day;
      }
      _page = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = MemberRange(widget.id, ProgressRange(_start, _end));
    final dataAsync = ref.watch(memberNutritionProvider(key));

    return dataAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            SizedBox(height: 12),
            SkeletonCard(height: 150),
            SkeletonCard(height: 90),
            SkeletonCard(height: 90),
          ],
        ),
      ),
      error: (e, _) => MemberTabError(message: '$e'),
      data: _buildContent,
    );
  }

  Widget _buildContent(NutritionData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
      physics: const ClampingScrollPhysics(),
      children: [
        MemberTabRangeBar(
          preset: _preset,
          start: _start,
          end: _end,
          onPreset: _applyPreset,
          onPickStart: () => _pickDate(isStart: true),
          onPickEnd: () => _pickDate(isStart: false),
        ),
        const SizedBox(height: 12),
        _MacroDonut(data: data),
        const SizedBox(height: 12),
        _buildMealList(data.meals),
      ],
    );
  }

  Widget _buildMealList(List<MealRow> meals) {
    final totalPages = meals.isEmpty ? 1 : (meals.length / _pageSize).ceil();
    final safePage = _page.clamp(0, totalPages - 1);
    final start = safePage * _pageSize;
    final end = (start + _pageSize).clamp(0, meals.length);
    final slice = meals.isEmpty
        ? const <MealRow>[]
        : meals.sublist(start, end);

    if (meals.isEmpty) {
      return const MemberTabEmpty(
        icon: Icons.restaurant_menu,
        message: 'No meals logged in this window',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (meals.length > _pageSize)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${start + 1}–$end of ${meals.length}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextTertiary,
              ),
            ),
          ),
        ...slice.map((m) => _MealRowCard(meal: m)),
        if (meals.length > _pageSize) ...[
          const SizedBox(height: 10),
          MemberTabPager(
            page: safePage,
            totalPages: totalPages,
            onPage: (p) => setState(() => _page = p),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Macro donut — protein / carbs / fat by calorie share
// ---------------------------------------------------------------------------

class _MacroDonut extends StatelessWidget {
  final NutritionData data;
  const _MacroDonut({required this.data});

  @override
  Widget build(BuildContext context) {
    // Calories per gram: protein 4, carbs 4, fat 9 — same math the member's
    // own meal page uses, so the donut splits match.
    final protCal = data.proteinG * 4;
    final carbCal = data.carbsG * 4;
    final fatCal = data.fatG * 9;
    final macroTotal = protCal + carbCal + fatCal;
    final hasData = macroTotal > 0;

    final sections = hasData
        ? <PieChartSectionData>[
            PieChartSectionData(
              value: protCal,
              color: const Color(0xFF0A84FF),
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: carbCal,
              color: const Color(0xFFFF9500),
              radius: 20,
              showTitle: false,
            ),
            PieChartSectionData(
              value: fatCal,
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

    return GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Nutrition',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${data.totalKcal} kcal · ${data.meals.length} meal${data.meals.length == 1 ? '' : 's'}',
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
          Row(
            children: [
              SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 32,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${data.totalKcal}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'kcal',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: ClayTokens.clayDarkTextTertiary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _MacroLegend(
                      color: const Color(0xFF0A84FF),
                      label: 'Protein',
                      grams: data.proteinG,
                    ),
                    const SizedBox(height: 8),
                    _MacroLegend(
                      color: const Color(0xFFFF9500),
                      label: 'Carbs',
                      grams: data.carbsG,
                    ),
                    const SizedBox(height: 8),
                    _MacroLegend(
                      color: const Color(0xFF30D158),
                      label: 'Fat',
                      grams: data.fatG,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


class _MacroLegend extends StatelessWidget {
  final Color color;
  final String label;
  final double grams;
  const _MacroLegend({
    required this.color,
    required this.label,
    required this.grams,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ClayTokens.clayDarkTextSecondary,
            ),
          ),
        ),
        Text(
          '${grams.toStringAsFixed(0)} g',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}


// ---------------------------------------------------------------------------
// Meal row + photo viewer
// ---------------------------------------------------------------------------

class _MealRowCard extends StatelessWidget {
  final MealRow meal;
  const _MealRowCard({required this.meal});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = meal.photoUrl != null && meal.photoUrl!.isNotEmpty;
    final mealLabel =
        meal.mealType.trim().isEmpty ? 'Meal' : meal.mealType.trim();

    return GlassPanel(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          GestureDetector(
            onTap: hasPhoto ? () => _openPhoto(context, meal.photoUrl!) : null,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF30D158).withAlpha(30),
                borderRadius: BorderRadius.circular(10),
                image: hasPhoto
                    ? DecorationImage(
                        image: NetworkImage(meal.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: hasPhoto
                  ? null
                  : const Icon(
                      Icons.restaurant_menu,
                      size: 20,
                      color: Color(0xFF30D158),
                    ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal.foodName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$mealLabel · ${DateFormat('h:mm a').format(meal.mealTime)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: ClayTokens.clayDarkTextTertiary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${meal.calories} kcal · '
                  'P ${meal.proteinG.toStringAsFixed(0)}g · '
                  'C ${meal.carbsG.toStringAsFixed(0)}g · '
                  'F ${meal.fatG.toStringAsFixed(0)}g',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: ClayTokens.clayDarkTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (hasPhoto)
            GestureDetector(
              onTap: () => _openPhoto(context, meal.photoUrl!),
              behavior: HitTestBehavior.opaque,
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 18,
                  color: ClayTokens.clayDarkTextSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(210),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const SizedBox(
                    height: 220,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => const SizedBox(
                  height: 220,
                  child: Center(
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 34,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white,
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

