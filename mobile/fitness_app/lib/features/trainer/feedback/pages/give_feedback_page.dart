import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared/models/trainer_feedback.dart';
import 'package:shared/services/feedback_service.dart';
import 'package:shared/services/notification_service.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';

final assignedMembersProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, trainerId) async {
  final response = await SupabaseClientService()
      .client
      .from('trainer_assignments')
      .select('member_id, profiles!trainer_assignments_member_id_fkey(full_name)')
      .eq('trainer_id', trainerId)
      .eq('status', 'active');
  return (response as List).cast<Map<String, dynamic>>();
});

final memberLogsPreviewProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, memberId) async {
  final response = await SupabaseClientService()
      .client
      .from('workout_logs')
      .select('*')
      .eq('member_id', memberId)
      .order('logged_at', ascending: false)
      .limit(5);
  return (response as List).cast<Map<String, dynamic>>();
});

/// Average star rating this trainer has received (relocated from the
/// trainer profile page so the rating lives on the Feedback screen).
final trainerRatingSummaryProvider = FutureProvider.family<Map<String, dynamic>, String>(
    (ref, trainerId) => FeedbackService().getRatingSummary(trainerId));

/// History of feedback this trainer has written (with member's rating embedded).
final givenFeedbackProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
    (ref, trainerId) => FeedbackService().getGivenFeedback(trainerId));

/// Figure 27: the Trainer gives written feedback to an assigned member.
/// Wires the previously-dead FeedbackService.submitFeedback.
class GiveFeedbackPage extends ConsumerStatefulWidget {
  const GiveFeedbackPage({super.key});

  @override
  ConsumerState<GiveFeedbackPage> createState() => _GiveFeedbackPageState();
}

class _GiveFeedbackPageState extends ConsumerState<GiveFeedbackPage> {
  String? _selectedMemberId;
  String? _selectedMemberName;
  final _contentController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final memberId = _selectedMemberId;
    if (memberId == null || _contentController.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final trainerId = SupabaseClientService().client.auth.currentUser!.id;
      await FeedbackService().submitFeedback(TrainerFeedback(
        id: '',
        trainerId: trainerId,
        memberId: memberId,
        content: _contentController.text.trim(),
        createdAt: DateTime.now(),
      ));
      // Figure 20: the system sends a notification to the Member.
      try {
        await NotificationService().createNotification(
          userId: memberId,
          title: 'New feedback from your trainer',
          body: _contentController.text.trim(),
        );
      } catch (_) {
        // The feedback itself is saved; the notification is best-effort.
      }
      if (mounted) {
        _contentController.clear();
        ref.invalidate(givenFeedbackProvider(trainerId));
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Feedback sent.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send feedback: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trainerId = SupabaseClientService().client.auth.currentUser!.id;
    final membersAsync = ref.watch(assignedMembersProvider(trainerId));

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      onPressed: () => context.pop(),
                      child: const Icon(CupertinoIcons.back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Give Feedback',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  children: [
                    Consumer(
                      builder: (context, ref, _) {
                        final ratingAsync = ref.watch(trainerRatingSummaryProvider(trainerId));
                        return ratingAsync.when(
                          data: (summary) {
                            final count = summary['count'] as int;
                            final average = (summary['average'] as num?)?.toDouble() ?? 0.0;
                            if (count == 0) return const SizedBox.shrink();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFC107).withAlpha(25),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withAlpha(18)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 22),
                                  const SizedBox(width: 8),
                                  Text(
                                    average.toStringAsFixed(1),
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  const Text(' / 5', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93))),
                                  const Spacer(),
                                  Text(
                                    '$count member rating${count == 1 ? '' : 's'}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                                  ),
                                ],
                              ),
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    membersAsync.when(
                      data: (members) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: ClayTokens.clayDarkSurfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withAlpha(25)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: _selectedMemberId,
                                hint: const Text('Select a member', style: TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                                dropdownColor: ClayTokens.clayDarkSurface,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF8E8E93), size: 22),
                                items: members.map((m) {
                                  final id = m['member_id'] as String;
                                  final name = (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown';
                                  return DropdownMenuItem(
                                    value: id,
                                    child: Text(name, style: const TextStyle(fontSize: 14, color: Colors.white)),
                                  );
                                }).toList(),
                                onChanged: (id) {
                                  if (id == null) return;
                                  setState(() {
                                    _selectedMemberId = id;
                                    _selectedMemberName = (members
                                            .firstWhere((m) => m['member_id'] == id)['profiles']
                                        as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown';
                                  });
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CupertinoActivityIndicator())),
                      error: (e, _) => Text('Error: $e', style: const TextStyle(fontSize: 12, color: Color(0xFFFF453A))),
                    ),
                    if (_selectedMemberId != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Recent workouts — $_selectedMemberName',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93)),
                      ),
                      const SizedBox(height: 6),
                      Consumer(
                        builder: (context, ref, _) {
                          final logsAsync = ref.watch(memberLogsPreviewProvider(_selectedMemberId!));
                          return logsAsync.when(
                            data: (logs) => logs.isEmpty
                                ? const Text('No workouts logged yet.', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)))
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: logs.map((w) {
                                      final name = (w['exercise_name'] ?? w['workout_name'] ?? 'Workout session').toString();
                                      final when = DateTime.tryParse(w['logged_at']?.toString() ?? '');
                                      final day = when == null ? '' : DateFormat('MMM d').format(when.toLocal());
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4),
                                        child: Text(
                                          day.isEmpty ? '• $name' : '• $name — $day',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF8E8E93)),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 6),
                              child: LinearProgressIndicator(minHeight: 2, color: Color(0xFFBF5AF2)),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          );
                        },
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Your feedback', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                    const SizedBox(height: 6),
                    CupertinoTextField(
                      controller: _contentController,
                      placeholder: 'Encouragement, form corrections, next focus...',
                      placeholderStyle: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextTertiary),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A4E),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: ClayTokens.clayDarkBorder),
                      ),
                      maxLines: 5,
                      minLines: 3,
                      cursorColor: ClayTokens.clayPrimary,
                      style: ClayTokens.bodyMedium.copyWith(color: ClayTokens.clayDarkTextPrimary),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFFF453A))),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        color: const Color(0xFFBF5AF2),
                        borderRadius: BorderRadius.circular(12),
                        onPressed: (_saving || _selectedMemberId == null || _contentController.text.trim().isEmpty) ? null : _submit,
                        child: _saving
                            ? const CupertinoActivityIndicator(color: Colors.white)
                            : const Text(
                                'Send feedback',
                                style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Feedback history', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                    const SizedBox(height: 8),
                    Consumer(
                      builder: (context, ref, _) {
                        final historyAsync = ref.watch(givenFeedbackProvider(trainerId));
                        return historyAsync.when(
                          data: (rows) => rows.isEmpty
                              ? const Text('No feedback sent yet.', style: TextStyle(fontSize: 12, color: Color(0xFF8E8E93)))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: rows.map((row) {
                                    final member = (row['member'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Member';
                                    final content = row['content'] as String? ?? '';
                                    final rating = row['rating'] as int?;
                                    final created = DateTime.tryParse(row['created_at']?.toString() ?? '');
                                    final day = created == null ? '' : DateFormat('MMM d, yyyy').format(created.toLocal());
                                    return Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: ClayTokens.clayPrimaryLight.withAlpha(25),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.white.withAlpha(18)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('$member · $day',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                          const SizedBox(height: 6),
                                          Text(content, style: const TextStyle(fontSize: 13, color: Color(0xFFB4B4D0))),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              for (int i = 1; i <= 5; i++)
                                                Icon(
                                                  i <= (rating ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                                                  size: 15,
                                                  color: i <= (rating ?? 0) ? const Color(0xFFFFC107) : const Color(0xFF8E8E93),
                                                ),
                                              const SizedBox(width: 6),
                                              Text(
                                                rating == null ? 'Not rated yet' : '$rating / 5',
                                                style: const TextStyle(fontSize: 11, color: Color(0xFF8E8E93)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: LinearProgressIndicator(minHeight: 2, color: Color(0xFFBF5AF2)),
                          ),
                          error: (_, __) => const SizedBox.shrink(),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}