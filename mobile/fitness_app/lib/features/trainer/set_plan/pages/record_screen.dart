import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../../features/shared/widgets/app_glow_background.dart';
import '../../../../features/shared/widgets/glass_card.dart';
import '../data/plan_repository.dart';

final trainerPlanRecordsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
      final repo = PlanRepository();
      return await repo.getTrainerPlanRecords(
        SupabaseClientService().client.auth.currentUser!.id,
      );
    });

final trainerPlanCancellationRequestsProvider =
    FutureProvider.autoDispose<Map<String, Map<String, dynamic>>>((ref) async {
      final client = SupabaseClientService().client;
      final trainerId = client.auth.currentUser?.id;
      if (trainerId == null) return {};
      final rows = await client
          .from('trainer_plan_cancellation_requests')
          .select('plan_id, member_id')
          .eq('trainer_id', trainerId)
          .eq('status', 'pending');
      return {
        for (final row in (rows as List).cast<Map<String, dynamic>>())
          row['plan_id'] as String: row,
      };
    });

class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(trainerPlanRecordsProvider);
    final cancellationRequests =
        ref.watch(trainerPlanCancellationRequestsProvider).valueOrNull ?? {};

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withAlpha(20)),
                  ),
                  child: Row(
                    children: [
                      _recordTab(
                        'Active',
                        !_showHistory,
                        () => setState(() => _showHistory = false),
                      ),
                      const SizedBox(width: 8),
                      _recordTab(
                        'History',
                        _showHistory,
                        () => setState(() => _showHistory = true),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: recordsAsync.when(
                  data: (records) {
                    final visibleRecords = records.where((record) {
                      final plan = record['plan'] as Map<String, dynamic>;
                      final status = plan['status'] as String? ?? 'active';
                      final isComplete =
                          status == 'active' &&
                          ((record['completion_pct'] as num?)?.toDouble() ??
                                  0) >=
                              1;
                      final isHistory = status != 'active' || isComplete;
                      return _showHistory ? isHistory : !isHistory;
                    }).toList();
                    if (visibleRecords.isEmpty) {
                      return const Center(
                        child: Text(
                          'No plans in this list yet',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      );
                    }
                    return AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: ListView.builder(
                        key: ValueKey(_showHistory),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: visibleRecords.length,
                        itemBuilder: (context, index) {
                          final record = visibleRecords[index];
                          final plan = record['plan'] as Map<String, dynamic>;
                          final memberProfile =
                              plan['profiles'] as Map<String, dynamic>? ?? {};
                          final memberName =
                              memberProfile['full_name'] as String? ??
                              'Unknown Member';
                          final memberId = plan['member_id'] as String? ?? '';
                          final completedDays =
                              record['completed_days'] as int? ?? 0;
                          final totalDays = record['total_days'] as int? ?? 7;
                          final startDate = plan['start_date'] as String? ?? '';
                          final endDate = plan['end_date'] as String? ?? '';
                          final completionPct =
                              record['completion_pct'] as double? ?? 0.0;
                          final status = plan['status'] as String? ?? 'active';
                          final isActive = !_showHistory && status == 'active';
                          final cancellationRequest =
                              cancellationRequests[plan['id'] as String];
                          final hasCancellationRequest =
                              cancellationRequest != null;

                          return GlassPanel(
                            margin: const EdgeInsets.only(bottom: 12),
                            borderRadius: BorderRadius.circular(16),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: memberId.isEmpty
                                    ? null
                                    : () => context.push(
                                        '/trainer/records/$memberId'
                                        '?name=${Uri.encodeComponent(memberName)}',
                                      ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: ClayTokens
                                                .clayPrimaryLight
                                                .withAlpha(35),
                                            child: Text(
                                              memberName
                                                  .split(' ')
                                                  .map((n) => n[0])
                                                  .take(2)
                                                  .join()
                                                  .toUpperCase(),
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
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: completionPct >= 1.0
                                                  ? const Color(
                                                      0xFF30D158,
                                                    ).withAlpha(25)
                                                  : ClayTokens.clayPrimary
                                                        .withAlpha(25),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              '$completedDays/$totalDays days',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: completionPct >= 1.0
                                                    ? const Color(0xFF30D158)
                                                    : ClayTokens
                                                          .clayPrimaryLight,
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
                                          backgroundColor: const Color(
                                            0xFF2A2A45,
                                          ),
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                completionPct >= 1.0
                                                    ? const Color(0xFF30D158)
                                                    : ClayTokens.clayPrimary,
                                              ),
                                        ),
                                      ),
                                      if (_showHistory)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 10,
                                            ),
                                            child: Text(
                                              status == 'cancelled'
                                                  ? 'CANCELLED'
                                                  : 'COMPLETED',
                                              style: TextStyle(
                                                color: status == 'cancelled'
                                                    ? const Color(0xFFFF453A)
                                                    : const Color(0xFF30D158),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (isActive && hasCancellationRequest)
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              const Padding(
                                                padding: EdgeInsets.only(
                                                  top: 10,
                                                  bottom: 4,
                                                ),
                                                child: Text(
                                                  'MEMBER REQUESTED CANCELLATION',
                                                  style: TextStyle(
                                                    color: Color(0xFFFF9A93),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                              TextButton.icon(
                                                onPressed: () async {
                                                  final confirmed =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) =>
                                                            _PlanCancelDialog(
                                                              onKeep: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                              onCancel: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                            ),
                                                      );
                                                  if (confirmed == true) {
                                                    try {
                                                      await PlanRepository()
                                                          .cancelPlan(
                                                            plan['id']
                                                                as String,
                                                          );
                                                      await SupabaseClientService()
                                                          .client
                                                          .from(
                                                            'trainer_plan_cancellation_requests',
                                                          )
                                                          .update({
                                                            'status':
                                                                'approved',
                                                            'reviewed_at':
                                                                DateTime.now()
                                                                    .toIso8601String(),
                                                          })
                                                          .eq(
                                                            'plan_id',
                                                            plan['id']
                                                                as String,
                                                          )
                                                          .eq(
                                                            'status',
                                                            'pending',
                                                          );
                                                      ref.invalidate(
                                                        trainerPlanRecordsProvider,
                                                      );
                                                      ref.invalidate(
                                                        trainerPlanCancellationRequestsProvider,
                                                      );
                                                      await NotificationService()
                                                          .createNotification(
                                                            userId:
                                                                cancellationRequest['member_id']
                                                                    as String,
                                                            title:
                                                                'Plan cancellation approved',
                                                            body:
                                                                'Your trainer approved your plan cancellation request.',
                                                          );
                                                    } catch (error) {
                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Could not approve cancellation: $error',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    }
                                                  }
                                                },
                                                icon: const Icon(
                                                  CupertinoIcons.xmark_circle,
                                                  color: Colors.white,
                                                  size: 17,
                                                ),
                                                label: const Text(
                                                  'Cancel plan',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFFDC2626,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CupertinoActivityIndicator(color: Color(0xFFD6A5FF)),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      style: const TextStyle(color: Color(0xFFFF453A)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordTab(String label, bool selected, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: selected
                  ? const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)],
                    )
                  : null,
              color: selected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF8E8E93),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.go('/trainer/profile'),
            child: const Icon(CupertinoIcons.back, color: Colors.white),
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

class _PlanCancelDialog extends StatelessWidget {
  final VoidCallback onKeep;
  final VoidCallback onCancel;
  const _PlanCancelDialog({required this.onKeep, required this.onCancel});

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.transparent,
    child: GlassPanel(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Cancel trainer plan?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'The member will no longer see this plan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onKeep,
                  style: FilledButton.styleFrom(
                    backgroundColor: ClayTokens.clayPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Keep plan'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onCancel,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
