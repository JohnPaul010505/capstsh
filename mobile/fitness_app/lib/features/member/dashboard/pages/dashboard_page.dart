import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared/services/supabase_client.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/clay/clay_card.dart';

final dashboardStatsProvider = FutureProvider((ref) async {
  final userId = SupabaseClientService().client.auth.currentUser!.id;
  final activeGoal = await SupabaseClientService()
      .client
      .from('goals')
      .select('id')
      .eq('member_id', userId)
      .eq('status', 'active');
  final unreadNotifications = await SupabaseClientService()
      .client
      .from('notifications')
      .select('id')
      .eq('user_id', userId)
      .eq('read', false);
  return {
    'goals': (activeGoal as List).length,
    'unread': (unreadNotifications as List).length,
  };
});

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: SafeArea(
        child: Column(
          children: [
            _buildNavBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                children: [
                  ClayFeatureCard(
                    icon: Icons.flag_outlined,
                    iconColor: ClayTokens.clayWarning,
                    title: '${statsAsync.value?['goals'] ?? 0} Active Goals',
                    onTap: () => context.go('/member/goals'),
                  ),
                  const SizedBox(height: 8),
                  ClayFeatureCard(
                    icon: Icons.notifications_outlined,
                    iconColor: ClayTokens.clayPrimary,
                    title: '${statsAsync.value?['unread'] ?? 0} Unread Notifications',
                    onTap: () => context.go('/member/notifications'),
                  ),
                  const SizedBox(height: 8),
                  ClayFeatureCard(
                    icon: Icons.restaurant,
                    iconColor: ClayTokens.clayPrimary,
                    title: 'Log Meals',
                    onTap: () => context.go('/member/meals'),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 12),
                    child: Text(
                      'Weekly Progress',
                      style: ClayTokens.headlineMedium.copyWith(
                        letterSpacing: -0.36,
                        color: ClayTokens.clayDarkTextPrimary,
                      ),
                    ),
                  ),
                  ClayCard(
                    variant: ClayCardVariant.elevated,
                    padding: ClayCardPadding.large,
                    child: Text(
                      'Your activity chart will appear here.',
                      textAlign: TextAlign.center,
                      style: ClayTokens.bodyLarge.copyWith(
                        fontSize: 15,
                        color: ClayTokens.clayDarkTextTertiary,
                        letterSpacing: -0.24,
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

  Widget _buildNavBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: ClayTokens.clayDarkBorder, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              'Dashboard',
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
