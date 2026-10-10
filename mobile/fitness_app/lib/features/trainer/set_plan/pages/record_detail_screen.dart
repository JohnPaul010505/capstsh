import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/app_glow_background.dart';
import '../../../../features/shared/widgets/glass_card.dart';
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
Future<(Map<String, Set<String>>, Map<String, Set<String>>)> _fetchCompletedByDay(
  String memberId,
  String startDate,
  String endDate,
) async {
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

    String dayOf(dynamic stamp) =>
        DateTime.parse(stamp.toString()).toLocal().toIso8601String().split('T').first;

    final workoutByDay = <String, Set<String>>{};
    for (final r in workouts as List) {
      final m = r as Map;
      final name = (m['exercise_name'] ?? '').toString();
      if (name.isEmpty) continue;
      workoutByDay.putIfAbsent(dayOf(m['logged_at']), () => <String>{}).add(_normPlanName(name));
    }
    final foodByDay = <String, Set<String>>{};
    for (final r in meals as List) {
      final m = r as Map;
      final name = (m['food_name'] ?? '').toString();
      if (name.isEmpty) continue;
      foodByDay.putIfAbsent(dayOf(m['meal_time']), () => <String>{}).add(_normPlanName(name));
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

  const RecordDetailScreen({
    super.key,
    required this.memberId,
    required this.memberName,
  });

  @override
  ConsumerState<RecordDetailScreen> createState() => _RecordDetailScreenState();
}

class _RecordDetailScreenState extends ConsumerState<RecordDetailScreen> {
  _RecordTab _tab = _RecordTab.workout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: FutureBuilder<Map<String, dynamic>?>(
            future: PlanRepository().getPlanByMember(widget.memberId),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)),
                );
              }
              final plan = snap.data;
              if (plan == null) {
                return Column(
                  children: [
                    _buildHeader(days: 0, total: 7),
                    const Expanded(
                      child: Center(
                        child: Text(
                          'No plan assigned yet',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      ),
                    ),
                  ],
                );
              }

              final startDate = plan['start_date'] as String? ?? '';
              final endDate = plan['end_date'] as String? ?? '';
              final notes = plan['notes'] as String?;
              final foodPlan = (plan['food_plan'] as List<dynamic>?) ?? const [];
              final exercisePlan = (plan['exercise_plan'] as List<dynamic>?) ?? const [];

              return FutureBuilder<(Map<String, Set<String>>, Map<String, Set<String>>)>(
                future: _fetchCompletedByDay(widget.memberId, startDate, endDate),
                builder: (context, doneSnap) {
                  final workoutByDay = doneSnap.data?.$1 ?? const <String, Set<String>>{};
                  final foodByDay = doneSnap.data?.$2 ?? const <String, Set<String>>{};
                  final base = _safeParse(startDate);

                  final workoutSections = _buildSections(
                    exercisePlan,
                    'exercises',
                    base,
                    (row, dayKey) => _exerciseItem(row, workoutByDay[dayKey] ?? const {}),
                  );
                  final foodSections = _buildSections(
                    foodPlan,
                    'foods',
                    base,
                    (row, dayKey) {
                      final name = (row['name'] ?? '').toString();
                      return (
                        text: name,
                        done: name.isNotEmpty &&
                            _planNameLogged(name, foodByDay[dayKey] ?? const {}),
                      );
                    },
                  );

                  final sections = _tab == _RecordTab.workout ? workoutSections : foodSections;
                  final doneCount = sections.fold<int>(
                    0,
                    (s, x) => s + x.items.where((i) => i.done).length,
                  );

                  return Column(
                    children: [
                      _buildHeader(days: doneCount, total: sections.length),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _tabPill(),
                              const SizedBox(height: 12),
                              Text(
                                'Schedule: $startDate — $endDate',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
                              ),
                              if (notes != null && notes.trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                GlassPanel(
                                  padding: const EdgeInsets.all(12),
                                  child: Text(
                                    notes,
                                    style: const TextStyle(fontSize: 13, color: Color(0xFFECECFC)),
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
                                      style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                                    ),
                                  ),
                                )
                              else
                                for (final s in sections)
                                  _PlanDaySection(day: s.day, title: s.title, items: s.items),
                            ],
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(20)),
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
                ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)])
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: const Icon(CupertinoIcons.back, color: Colors.white),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  widget.memberName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    decoration: TextDecoration.none,
                  ),
                ),
                const Text(
                  'Records',
                  textAlign: TextAlign.center,
                  style: TextStyle(
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
    for (final group in planColumn) {
      if (group is! Map) continue;
      final dayNum = group['day'];
      if (dayNum is! int) continue;
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
      sections.add(_SectionData(
        day: dayNum,
        title: nestedKey == 'foods' ? 'Meals' : 'Exercises',
        items: items,
      ));
    }
    return sections;
  }

  String _dayKeyFor(DateTime base, int dayNum) {
    final d = DateTime(base.year, base.month, base.day).add(Duration(days: dayNum - 1));
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
  _SectionData({required this.day, required this.title, required this.items});
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

  const _PlanDaySection({
    required this.day,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final doneCount = items.where((i) => i.done).length;
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
                if (doneCount > 0)
                  Text(
                    '$doneCount/${items.length} done',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF30D158),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      item.done ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 13,
                      color: item.done ? const Color(0xFF30D158) : const Color(0xFF8E8E93),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.text,
                        style: TextStyle(
                          fontSize: 13,
                          decoration: item.done ? TextDecoration.lineThrough : TextDecoration.none,
                          color: item.done ? const Color(0xFF8E8E93) : const Color(0xFFECECFC),
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

