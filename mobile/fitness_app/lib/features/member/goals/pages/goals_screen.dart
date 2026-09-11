import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'package:shared/services/notification_service.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/app_glow_background.dart';
import 'create_goal_card.dart';
import 'goal_card.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

final goalsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final response = await SupabaseClientService().client
      .from('goals')
      .select()
      .eq('member_id', userId)
      .order('created_at', ascending: false);
  return response;
});

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return CupertinoPageScaffold(
      backgroundColor: bgDark,
      child: AppGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader('Goals'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  children: [
                    CreateGoalCard(
                      onGoalAdded: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Goal created'),
                            backgroundColor: const Color(0xFF22C55E),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                    goalsAsync.when(
                      data: (goals) => goals.isEmpty
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(top: 24),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: cardDark,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: goals.asMap().entries.map((entry) {
                                    final g = entry.value;
                                    return GoalCard(
                                      goal: g,
                                      onToggleStatus: () async {
                                        final currentStatus = g['status'] as String? ?? 'active';
                                        final newStatus = currentStatus == 'active' ? 'completed' : 'active';
                                        await SupabaseClientService().client
                                            .from('goals')
                                            .update({'status': newStatus})
                                            .eq('id', g['id']);
                                        final userId = SupabaseClientService().client.auth.currentUser!.id;
                                        if (newStatus == 'completed') {
                                          await NotificationService().createNotification(
                                            userId: userId,
                                            title: 'Goal Completed',
                                            body: 'Congratulations! You completed your ${g['goal_type'] ?? 'fitness'} goal.',
                                          );
                                        }
                                        ref.invalidate(goalsProvider);
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                      loading: () => const Center(child: CupertinoActivityIndicator()),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Error: $e',
                          style: TextStyle(color: Colors.redAccent, fontSize: 14),
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
    );
  }

  Widget _buildHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: () => context.pop(),
            child: Icon(
              CupertinoIcons.back,
              color: ClayTokens.clayPrimary,
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: ClayTokens.titleLarge.copyWith(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: ClayTokens.clayDarkTextPrimary,
                letterSpacing: -0.41,
              ),
            ),
          ),
          const SizedBox(width: 32),
        ],
      ),
    );
  }
}
