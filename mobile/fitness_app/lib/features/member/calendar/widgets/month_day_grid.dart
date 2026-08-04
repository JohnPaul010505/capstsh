import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';

/// Reusable month calendar grid: month header (chevron + label), weekday
/// labels and the day grid. Shared by the dedicated calendar page and the
/// workout screen's flip card front face.
class MonthDayGrid extends StatelessWidget {
  final DateTime visibleMonth;
  final DateTime selected;
  final DateTime today;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> meals;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<int> onShiftMonth;

  const MonthDayGrid({
    super.key,
    required this.visibleMonth,
    required this.selected,
    required this.today,
    required this.workouts,
    required this.meals,
    required this.onDayTap,
    required this.onShiftMonth,
  });

  String _monthName(int m) {
    const names = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return names[m - 1];
  }

  Widget _dot(Color color) => Container(
    width: 5, height: 5,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  @override
  Widget build(BuildContext context) {
    final first = DateTime(visibleMonth.year, visibleMonth.month, 1);
    final daysInMonth = DateTime(visibleMonth.year, visibleMonth.month + 1, 0).day;
    final leading = first.weekday % 7; // Sunday = 0 leading cells (PH Sunday-first grid)

    final workoutByDay = <int, List<Map<String, dynamic>>>{};
    for (final w in workouts) {
      final t = DateTime.tryParse(w['logged_at'] as String? ?? '')?.toLocal();
      if (t != null) (workoutByDay[t.day] ??= []).add(w);
    }
    final mealByDay = <int, List<Map<String, dynamic>>>{};
    for (final m in meals) {
      final t = DateTime.tryParse(m['meal_time'] as String? ?? '')?.toLocal();
      if (t != null) (mealByDay[t.day] ??= []).add(m);
    }

    final cells = <Widget>[];
    for (int i = 0; i < leading; i++) {
      cells.add(const Expanded(child: SizedBox()));
    }
    for (int d = 1; d <= daysInMonth; d++) {
      final isToday = visibleMonth.year == today.year &&
          visibleMonth.month == today.month && d == today.day;
      final isFuture = visibleMonth.year == today.year &&
          visibleMonth.month == today.month && d > today.day;
      final isSelected = selected.year == visibleMonth.year &&
          selected.month == visibleMonth.month && d == selected.day;
      final ws = workoutByDay[d] ?? [];
      final ms = mealByDay[d] ?? [];
      final wsHasVideo = ws.any((w) => w['proof_url'] != null);
      cells.add(Expanded(
        child: GestureDetector(
          onTap: () => onDayTap(DateTime(visibleMonth.year, visibleMonth.month, d)),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isToday ? ClayTokens.clayPrimary.withAlpha(22) : ClayTokens.clayDarkSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? ClayTokens.clayPrimaryLight
                    : isToday
                        ? ClayTokens.clayPrimaryLight.withAlpha(80)
                        : ClayTokens.clayDarkBorder.withAlpha(80),
                width: isSelected ? 1.6 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday
                        ? ClayTokens.clayPrimaryLight
                        : isFuture
                            ? ClayTokens.clayDarkTextTertiary.withAlpha(140)
                            : ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (ws.isNotEmpty)
                      const Icon(Icons.fitness_center, size: 10, color: ClayColors.clayAccent),
                    if (wsHasVideo) ...[
                      const SizedBox(width: 3),
                      const Icon(Icons.play_circle, size: 10, color: ClayColors.clayPrimaryLight),
                    ],
                    if (ws.isNotEmpty && ms.isNotEmpty) const SizedBox(width: 3),
                    if (ms.isNotEmpty) _dot(ClayTokens.clayWarning),
                  ],
                ),
              ],
            ),
          ),
        ),
      ));
    }
    while (cells.length % 7 != 0) {
      cells.add(const Expanded(child: SizedBox()));
    }

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final rows = List.generate(
      cells.length ~/ 7,
      (row) => Expanded(
        child: Row(children: cells.sublist(row * 7, row * 7 + 7)),
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => onShiftMonth(-1),
                icon: Icon(Icons.chevron_left, color: ClayTokens.clayDarkTextTertiary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
              Text(
                '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
                style: ClayTokens.titleMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
              ),
              IconButton(
                onPressed: () => onShiftMonth(1),
                icon: Icon(Icons.chevron_right, color: ClayTokens.clayDarkTextTertiary, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: labels.map((l) => Expanded(
              child: Center(
                child: Text(l, style: ClayTokens.labelSmall.copyWith(color: ClayTokens.clayDarkTextTertiary)),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(children: rows),
          ),
        ),
      ],
    );
  }
}