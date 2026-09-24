import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/app_glow_background.dart';
import '../data/plan_repository.dart';

final trainerPlanRecordsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = PlanRepository();
  return await repo.getTrainerPlanRecords(
    SupabaseClientService().client.auth.currentUser!.id,
  );
});

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

                        return GestureDetector(
                          onTap: () {
                            context.push('/trainer/record/${plan['id']}');
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: ClayTokens.clayDarkSurfaceElevated,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(18)),
                            ),
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