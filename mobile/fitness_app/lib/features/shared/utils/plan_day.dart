/// Shared day arithmetic for trainer plans (`member_goal_plans`).
///
/// The trainer builds a plan as per-day groups
/// (`[{'day': 1, 'exercises'|'foods': [...]}, ...]`) whose Day 1 is the plan's
/// `start_date`. Day N therefore runs on `start_date + (N - 1)` days: Day 1 on
/// the start date, Day 2 once 24 hours (one calendar day) has passed, and so
/// on until the plan's last day.
library;

/// How many days the plan contains, from its per-day groups.
///
/// Returns the highest `day` value found (1..7 to match the
/// `plan_day_completions.day_number` check constraint and the trainer's
/// 7-day builder), falling back to the number of groups when they carry no
/// `day` key, and never less than 1.
int planDayCount(Object? planColumn) {
  if (planColumn is! List || planColumn.isEmpty) return 1;

  var maxDay = 0;
  for (final group in planColumn) {
    if (group is! Map) continue;
    final day = group['day'];
    if (day is num && day.toInt() > maxDay) maxDay = day.toInt();
  }
  if (maxDay < 1) maxDay = planColumn.length;
  if (maxDay < 1) return 1;
  return maxDay > 7 ? 7 : maxDay;
}

/// The plan day that is active on today's date.
///
/// [startDate] is the plan's `start_date` (`yyyy-MM-dd`); [totalDays] is the
/// plan's day count from [planDayCount]. Counting whole calendar days in UTC
/// keeps the result stable across DST changes: on the start date itself the
/// member sees Day 1, one calendar day later Day 2, and so on.
///
/// Days are clamped into `1..totalDays`, so a plan whose start date is still
/// in the future shows Day 1 and a plan that has run past its last day keeps
/// showing its last day.
int activePlanDay({
  required String? startDate,
  required int totalDays,
  DateTime? now,
}) {
  final start = DateTime.tryParse((startDate ?? '').trim());
  if (start == null) return 1;

  final reference = now ?? DateTime.now();
  final elapsed = DateTime
      .utc(reference.year, reference.month, reference.day)
      .difference(DateTime.utc(start.year, start.month, start.day))
      .inDays;

  final lastDay = totalDays < 1 ? 1 : (totalDays > 7 ? 7 : totalDays);
  final day = elapsed + 1;
  if (day < 1) return 1;
  if (day > lastDay) return lastDay;
  return day;
}
