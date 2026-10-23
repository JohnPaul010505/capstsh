/// Pending requests stay actionable even if the scheduled window has ended.
bool trainerPlanIsHistory(
  Map<String, dynamic> record, {
  required bool hasPendingCancellation,
  DateTime? now,
}) {
  final plan = record['plan'] as Map;
  if ((plan['status'] ?? 'active') != 'active') return true;
  if (hasPendingCancellation) return false;
  if (record['fully_completed'] == true) return true;
  final date = now ?? DateTime.now();
  final today = DateTime(date.year, date.month, date.day);
  final end = DateTime.tryParse(plan['end_date']?.toString() ?? '');
  return end != null && end.isBefore(today);
}
