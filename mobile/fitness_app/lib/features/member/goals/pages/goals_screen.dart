import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import 'create_goal_card.dart';
import 'goal_card.dart';
import 'empty_goals_state.dart';

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

    return Scaffold(
      backgroundColor: bgDark,
      body: SafeArea(
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
                  const CreateGoalCard(),
                  const SizedBox(height: 24),
                  _buildMyGoalsHeader(),
                  const SizedBox(height: 12),
                  goalsAsync.when(
                    data: (goals) => goals.isEmpty
                        ? const EmptyGoalsState()
                        : Container(
                            decoration: BoxDecoration(
                              color: cardDark,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Column(
                              children: goals.asMap().entries.map((entry) {
                                final g = entry.value;
                                final isLast = entry.key == goals.length - 1;
                                return GoalCard(
                                  goal: g,
                                  isLast: isLast,
                                  onToggleStatus: () async {
                                    final currentStatus = g['status'] as String? ?? 'active';
                                    final newStatus = currentStatus == 'active' ? 'completed' : 'active';
                                    await SupabaseClientService().client
                                        .from('goals')
                                        .update({'status': newStatus})
                                        .eq('id', g['id']);
                                    ref.invalidate(goalsProvider);
                                  },
                                );
                              }).toList(),
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
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: primaryPurple.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CupertinoButton(
              padding: const EdgeInsets.all(10),
              onPressed: () => context.pop(),
              child: Icon(CupertinoIcons.back, color: primaryPurple, size: 20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Set and track your fitness goals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: primaryPurple.withAlpha(25),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(CupertinoIcons.flag, color: primaryPurple, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildMyGoalsHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'My Goals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.36,
            ),
          ),
        ),
        CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {},
          child: Text(
            'View All',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: primaryPurple,
              fontSize: 14,
            ),
          ),
        ),
        Icon(CupertinoIcons.chevron_right, color: primaryPurple, size: 18),
      ],
    );
  }
}
