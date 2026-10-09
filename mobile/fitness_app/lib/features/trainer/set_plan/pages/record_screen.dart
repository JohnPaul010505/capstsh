import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/app_glow_background.dart';
import '../../../../features/shared/widgets/glass_card.dart';
import '../data/plan_repository.dart';

final trainerPlanRecordsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = PlanRepository();
  return await repo.getTrainerPlanRecords(
    SupabaseClientService().client.auth.currentUser!.id,
  );
});

String _normPlanName(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Loads the member's logged exercise/food names within the plan window so
/// the record sheet can cross out completed tasks. RLS already lets a
/// trainer read assigned members' workout_logs and meal_logs; any failure
/// degrades to "nothing crossed out" instead of breaking the sheet.
Future<(Set<String>, Set<String>)> _fetchCompletedNames(
  String memberId,
  String startDate,
  String endDate,
) async {
  try {
    final start = DateTime.parse(startDate).toUtc();
    final end = DateTime.parse(endDate)
        .add(const Duration(days: 1))
        .toUtc();
    final client = SupabaseClientService().client;
    final workouts = await client
        .from('workout_logs')
        .select('exercise_name')
        .eq('member_id', memberId)
        .gte('logged_at', start.toIso8601String())
        .lt('logged_at', end.toIso8601String());
    final meals = await client
        .from('meal_logs')
        .select('food_name')
        .eq('member_id', memberId)
        .gte('meal_time', start.toIso8601String())
        .lt('meal_time', end.toIso8601String());
    final workoutNames = {
      for (final r in workouts as List)
        if (((r as Map)['exercise_name'] ?? '').toString().isNotEmpty)
          _normPlanName(r['exercise_name'].toString()),
    };
    final foodNames = {
      for (final r in meals as List)
        if (((r as Map)['food_name'] ?? '').toString().isNotEmpty)
          _normPlanName(r['food_name'].toString()),
    };
    return (workoutNames, foodNames);
  } catch (_) {
    return (<String>{}, <String>{});
  }
}

/// Formats one exercise entry as "Name — 3 sets · 12 reps · 60kg" plus its
/// done state (the member logged that exercise name within the plan window).
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
    done: workoutNames.contains(_normPlanName(name)),
  );
}

class RecordScreen extends ConsumerWidget {
  const RecordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(trainerPlanRecordsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Expanded(
                child: recordsAsync.when(
                  data: (records) {
                    if (records.isEmpty) {
                      return const Center(
                        child: Text(
                          'No plans assigned yet',
                          style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93)),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: records.length,
                      itemBuilder: (context, index) {
                        final record = records[index];
                        final plan = record['plan'] as Map<String, dynamic>;
                        final memberProfile = plan['profiles'] as Map<String, dynamic>? ?? {};
                        final memberName = memberProfile['full_name'] as String? ?? 'Unknown Member';
                        final completedDays = record['completed_days'] as int? ?? 0;
                        final totalDays = record['total_days'] as int? ?? 7;
                        final startDate = plan['start_date'] as String? ?? '';
                        final endDate = plan['end_date'] as String? ?? '';
                        final completionPct = record['completion_pct'] as double? ?? 0.0;

                        return GlassPanel(
                          margin: const EdgeInsets.only(bottom: 12),
                          borderRadius: BorderRadius.circular(16),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                _showPlanDetails(context, record);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 20,
                                      backgroundColor: ClayTokens.clayPrimaryLight.withAlpha(35),
                                      child: Text(
                                        memberName.split(' ').map((n) => n[0]).take(2).join().toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: ClayTokens.clayPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            memberName,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFFFFFFF),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$startDate — $endDate',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: completionPct >= 1.0
                                            ? const Color(0xFF30D158).withAlpha(25)
                                            : ClayTokens.clayPrimary.withAlpha(25),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '$completedDays/$totalDays days',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: completionPct >= 1.0
                                              ? const Color(0xFF30D158)
                                              : ClayTokens.clayPrimaryLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: completionPct.clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFF2A2A45),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      completionPct >= 1.0
                                          ? const Color(0xFF30D158)
                                          : ClayTokens.clayPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ),
                        ),
                      );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error: $e', style: const TextStyle(color: Color(0xFFFF453A))),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPlanDetails(BuildContext context, Map<String, dynamic> record) {
    final plan = record['plan'] as Map<String, dynamic>;
    final memberProfile = plan['profiles'] as Map<String, dynamic>? ?? {};
    final memberName = memberProfile['full_name'] as String? ?? 'Unknown Member';
    final completedDays = record['completed_days'] as int? ?? 0;
    final totalDays = record['total_days'] as int? ?? 7;
    final startDate = plan['start_date'] as String? ?? '';
    final endDate = plan['end_date'] as String? ?? '';
    final notes = plan['notes'] as String?;
    final memberId = plan['member_id'] as String?;
    // The assigned plan itself (what the trainer built on Create Plan):
    // food_plan = [{day, foods: [{name, meal_type, ...}]}], same shape for
    // exercise_plan. Older rows may predate these columns — guard for null.
    final foodPlan = (plan['food_plan'] as List<dynamic>?) ?? const [];
    final exercisePlan = (plan['exercise_plan'] as List<dynamic>?) ?? const [];

    final completedFuture = memberId == null
        ? Future.value((<String>{}, <String>{}))
        : _fetchCompletedNames(memberId, startDate, endDate);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return GlassSheetShell(
          child: FutureBuilder<(Set<String>, Set<String>)>(
            future: completedFuture,
            builder: (context, snap) {
              final workoutNames = snap.data?.$1 ?? const <String>{};
              final foodNames = snap.data?.$2 ?? const <String>{};
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  32 + MediaQuery.of(ctx).padding.bottom,
                ),
                child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    memberName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedDays >= totalDays
                          ? const Color(0xFF30D158).withAlpha(25)
                          : ClayTokens.clayPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$completedDays/$totalDays days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: completedDays >= totalDays
                            ? const Color(0xFF30D158)
                            : ClayTokens.clayPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Schedule: $startDate — $endDate',
                style: const TextStyle(fontSize: 13, color: Color(0xFF8E8E93)),
              ),
              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    notes,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFECECFC)),
                  ),
                ),
              ],
              // Assigned plan breakdown — the same food/exercise data the
              // trainer built on the Create Plan screen, grouped by day.
              if (foodPlan.isNotEmpty || exercisePlan.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Assigned Plan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final Map dayEntry in foodPlan)
                      _PlanDaySection(
                        day: dayEntry['day'],
                        title: 'Meals',
                        items: [
                          for (final Map f
                              in (dayEntry['foods'] as List<dynamic>? ??
                                  const []))
                            if (((f['name'] ?? '').toString()).isNotEmpty)
                              (
                                text: (f['name'] ?? '').toString(),
                                done: foodNames.contains(
                                    _normPlanName((f['name'] ?? '').toString())),
                              ),
                        ],
                      ),
                    for (final Map dayEntry in exercisePlan)
                      _PlanDaySection(
                        day: dayEntry['day'],
                        title: 'Exercises',
                        items: [
                          for (final Map e
                              in (dayEntry['exercises'] as List<dynamic>? ??
                                  const []))
                            if (((e['name'] ?? '').toString()).isNotEmpty)
                              _exerciseItem(e, workoutNames),
                        ],
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              if (memberId != null)
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClayTokens.clayPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/trainer/members/$memberId');
                    },
                    child: const Text(
                      'View Member Progress',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.go('/trainer/profile'),
            child: const Icon(
              CupertinoIcons.back,
              color: Colors.white,
            ),
          ),
          const Expanded(
            child: Text(
              'Records',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Color(0xFFFFFFFF),
                decoration: TextDecoration.none,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}

/// One day's block of the assigned plan ("Day 1 Â· Meals" / "Day 1 Â·
/// Exercises") inside the plan-details sheet. Items the member has logged
/// render crossed out with a green check, so the trainer sees progress.
class _PlanDaySection extends StatelessWidget {
  final dynamic day;
  final String title;
  final List<({String text, bool done})> items;

  const _PlanDaySection({
    required this.day,
    required this.title,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final doneCount = items.where((i) => i.done).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Day $day Â· $title',
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
                              : const Color(0xFFECECFC),
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
