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
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Feedback sent.')),
        );
        context.pop();
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
                      child: Icon(CupertinoIcons.back, color: ClayTokens.clayPrimary),
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
                    membersAsync.when(
                      data: (members) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Member', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF8E8E93))),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: members.map((m) {
                              final id = m['member_id'] as String;
                              final name = (m['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ?? 'Unknown';
                              final selected = _selectedMemberId == id;
                              return ChoiceChip(
                                label: Text(name, style: TextStyle(fontSize: 12, color: selected ? Colors.white : const Color(0xFF8E8E93))),
                                selected: selected,
                                onSelected: (_) => setState(() {
                                  _selectedMemberId = id;
                                  _selectedMemberName = name;
                                }),
                                selectedColor: const Color(0xFFBF5AF2),
                                backgroundColor: const Color(0xFF2C2C2E),
                              );
                            }).toList(),
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