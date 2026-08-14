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
      cells.add(Expanded(
        child: GestureDetector(
          onTap: () => onDayTap(DateTime(visibleMonth.year, visibleMonth.month, d)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isToday
                  ? ClayTokens.clayPrimary.withAlpha(30)
                  : isSelected
                      ? Colors.white.withAlpha(12)
                      : Colors.white.withAlpha(5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? ClayTokens.clayPrimaryLight
                    : isToday
                        ? ClayTokens.clayPrimary.withAlpha(100)
                        : Colors.white.withAlpha(10),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$d',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isToday ? FontWeight.w800 : isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isToday
                        ? ClayTokens.clayPrimaryLight
                        : isFuture
                            ? ClayTokens.clayDarkTextTertiary.withAlpha(100)
                            : ClayTokens.clayDarkTextPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                if (ws.isNotEmpty || ms.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (ws.isNotEmpty)
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFF30D158),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (ws.isNotEmpty && ms.isNotEmpty) const SizedBox(width: 2),
                      if (ws.any((w) => w['proof_url'] != null))
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF453A),
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (ws.any((w) => w['proof_url'] != null) && ms.isNotEmpty) const SizedBox(width: 2),
                      if (ms.isNotEmpty)
                        Container(
                          width: 4, height: 4,
                          decoration: BoxDecoration(
                            color: ClayTokens.clayWarning,
                            shape: BoxShape.circle,
                          ),
                        ),
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
              GestureDetector(
                onTap: () => onShiftMonth(-1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chevron_left, color: ClayTokens.clayDarkTextTertiary, size: 20),
                ),
              ),
              Text(
                '${_monthName(visibleMonth.month)} ${visibleMonth.year}',
                style: ClayTokens.titleMedium.copyWith(
                  color: ClayTokens.clayDarkTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              GestureDetector(
                onTap: () => onShiftMonth(1),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.chevron_right, color: ClayTokens.clayDarkTextTertiary, size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: labels.map((l) => Expanded(
              child: Center(
                child: Text(l, style: ClayTokens.labelSmall.copyWith(
                  color: ClayTokens.clayDarkTextTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                )),
              ),
            )).toList(),
          ),
        ),
        const SizedBox(height: 6),
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
