import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared/providers/auth_provider.dart';
import '../features/auth/pages/login_page.dart';
import '../features/member/home/pages/home_page.dart';
import '../features/member/meals/pages/meal_log_page.dart';
import '../features/member/workout/pages/workout_page.dart';
import '../features/member/chat/pages/chat_page.dart';
import '../features/member/settings/pages/settings_page.dart';
import '../features/member/membership/pages/membership_page.dart';
import '../features/member/bmi/pages/bmi_page.dart';
import '../features/member/goals/pages/goals_page.dart';
import '../features/member/feedback/pages/feedback_page.dart';
import '../features/member/notifications/pages/notifications_page.dart';
import '../features/trainer/notifications/pages/notifications_page.dart';
import '../features/trainer/dashboard/pages/dashboard_page.dart' as trainer;
import '../features/trainer/progress/pages/progress_list_page.dart';
import '../features/trainer/progress/pages/member_progress_tabs.dart';
import '../features/trainer/insight/pages/member_insight_page.dart';
import '../features/trainer/insight/pages/member_insight_overview_page.dart';
import '../features/trainer/insight/pages/member_insight_search_page.dart';
import '../features/trainer/chat/pages/chat_list_page.dart';
import '../features/trainer/chat/pages/chat_room_page.dart';
import '../features/trainer/profile/pages/profile_page.dart' as trainer_profile;
import '../features/trainer/feedback/pages/give_feedback_page.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/create_plan_screen.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/record_screen.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/record_detail_screen.dart';
import '../features/shared/checkin/checkin_page.dart';
import '../features/shared/widgets/member_nav_bar.dart';
import '../features/member/onboarding/pages/onboarding_splash_screen.dart';
import '../features/shared/widgets/trainer_nav_bar.dart';

Page<dynamic> _iosPush(Widget child) => CustomTransitionPage(
  child: child,
  transitionsBuilder: (_, animation, __, child) {
    final scale = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    final fade = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: fade,
      child: ScaleTransition(scale: scale, child: child),
    );
  },
  transitionDuration: const Duration(milliseconds: 300),
  reverseTransitionDuration: const Duration(milliseconds: 250),
);

final needsOnboardingSyncProvider = Provider<bool>((ref) {
  final profile = ref.watch(authProvider).valueOrNull;
  if (profile == null || profile.role != 'member') return false;
  final gender = profile.gender;
  return gender == null || gender.trim().isEmpty;
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final needsOnboarding = ref.watch(needsOnboardingSyncProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final profile = authState.valueOrNull;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) {
        if (profile?.role == 'trainer') return '/trainer/dashboard';
        if (needsOnboarding) return '/member/onboarding';
        return '/member/home';
      }
      if (isLoggedIn && profile != null) {
        final loc = state.matchedLocation;
        if (needsOnboarding && loc != '/member/onboarding') {
          return '/member/onboarding';
        }
        if (profile.role == 'member' && loc.startsWith('/trainer')) {
          return '/member/home';
        }
        if (profile.role == 'member' && loc.startsWith('/admin')) {
          return '/member/home';
        }
        if (profile.role == 'trainer' && loc.startsWith('/member')) {
          return '/trainer/dashboard';
        }
        if (profile.role == 'trainer' && loc.startsWith('/admin')) {
          return '/trainer/dashboard';
        }
        if (profile.role == 'admin') return '/member/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        pageBuilder: (_, __) => _iosPush(const LoginPage()),
      ),
      GoRoute(
        path: '/member/onboarding',
        pageBuilder: (_, __) => _iosPush(const OnboardingSplashScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MemberShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/member/home',
                pageBuilder: (_, __) => _iosPush(const HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/member/workout',
                pageBuilder: (_, __) => _iosPush(const WorkoutPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/member/meals',
                pageBuilder: (_, __) => _iosPush(const MealLogPage()),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/member/settings',
        pageBuilder: (_, __) => _iosPush(const SettingsPage()),
      ),
      GoRoute(
        path: '/member/goals',
        pageBuilder: (_, __) => _iosPush(const GoalsPage()),
      ),
      GoRoute(
        path: '/member/feedback',
        pageBuilder: (_, __) => _iosPush(const FeedbackPage()),
      ),
      GoRoute(
        path: '/member/bmi',
        pageBuilder: (_, __) => _iosPush(const BmiPage()),
      ),
      GoRoute(
        path: '/member/notifications',
        pageBuilder: (_, __) => _iosPush(const NotificationsPage()),
      ),
      // Full-screen chat (pushed on the root navigator) so the member nav bar
      // is hidden while chatting and "<" pops back to the previous screen.
      GoRoute(
        path: '/member/chat',
        pageBuilder: (_, __) => _iosPush(const ChatPage()),
      ),
      // Full-screen QR check-in (pushed on the root navigator) so the member
      // nav bar is hidden on the scanner and "<" pops back to the previous
      // screen. Success returns to the member home.
      GoRoute(
        path: '/member/checkin',
        pageBuilder: (_, __) => _iosPush(
          const CheckinPage(
            showBack: true,
            returnRoute: '/member/home',
          ),
        ),
      ),
      GoRoute(
        path: '/member/membership',
        pageBuilder: (_, __) => _iosPush(const MembershipPage()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            TrainerShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/dashboard',
                pageBuilder: (_, __) => _iosPush(const trainer.DashboardPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/members',
                pageBuilder: (_, __) => _iosPush(const ProgressListPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/chat',
                pageBuilder: (_, __) => _iosPush(const ChatListPage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/profile',
                pageBuilder: (_, __) =>
                    _iosPush(const trainer_profile.ProfilePage()),
                routes: [
                  GoRoute(
                    path: 'notifications',
                    pageBuilder: (_, __) =>
                        _iosPush(const TrainerNotificationsPage()),
                  ),
                  GoRoute(
                    path: 'set-plan',
                    pageBuilder: (_, __) => _iosPush(const CreatePlanScreen()),
                  ),
                  GoRoute(
                    path: 'feedback',
                    pageBuilder: (_, __) => _iosPush(const GiveFeedbackPage()),
                  ),
                  GoRoute(
                    path: 'record',
                    pageBuilder: (_, __) => _iosPush(const RecordScreen()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      // Full-screen QR check-in (pushed on the root navigator) so the trainer
      // nav bar is hidden on the scanner and "<" pops back to the previous
      // screen. Success returns to the trainer dashboard.
      GoRoute(
        path: '/trainer/checkin',
        pageBuilder: (_, __) => _iosPush(
          const CheckinPage(
            showBack: true,
            returnRoute: '/trainer/dashboard',
          ),
        ),
      ),
      // Full-screen Member Progress (4 tabs: Overview / Workouts / Nutrition /
      // Check-ins) pushed on the root navigator so the trainer nav bar is
      // hidden while reviewing a member and "<" pops back to wherever the
      // trainer came from (Members list, dashboard attention rows, …).
      GoRoute(
        path: '/trainer/members/:id',
        pageBuilder: (_, state) => _iosPush(
          MemberProgressTabsPage(id: state.pathParameters['id']!),
        ),
      ),
      // Member Insight overview (date-filtered roster). Reachable directly;
      // the dashboard also embeds it as the 4th burger-menu screen.
      GoRoute(
        path: '/trainer/insight/overview',
        pageBuilder: (_, __) => _iosPush(const MemberInsightOverviewPage()),
      ),
      // Member Insight: dashboard search → pick a member → goal progress,
      // retention risk, check-ins and weight on one screen. Both pushed on
      // the root navigator so the trainer nav bar hides and "<" pops back
      // to wherever the trainer came from (dashboard or Members list).
      GoRoute(
        path: '/trainer/insight',
        pageBuilder: (_, __) => _iosPush(const MemberInsightSearchPage()),
      ),
      GoRoute(
        path: '/trainer/insight/:id',
        pageBuilder: (_, state) => _iosPush(
          MemberInsightPage(id: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/trainer/set-plan',
        pageBuilder: (_, __) => _iosPush(const CreatePlanScreen()),
      ),
      GoRoute(
        path: '/trainer/feedback',
        pageBuilder: (_, __) => _iosPush(const GiveFeedbackPage()),
      ),
      GoRoute(
        path: '/trainer/notifications',
        pageBuilder: (_, __) => _iosPush(const TrainerNotificationsPage()),
      ),
      GoRoute(
        path: '/trainer/record',
        pageBuilder: (_, __) => _iosPush(const RecordScreen()),
      ),
      // One member's plan, split into Workout / Foods tabs with per-day
      // completion crossing. Pushed on the root navigator so "<" pops back to
      // the records list.
      GoRoute(
        path: '/trainer/records/:memberId',
        pageBuilder: (_, state) => _iosPush(
          RecordDetailScreen(
            memberId: state.pathParameters['memberId']!,
            memberName: state.uri.queryParameters['name'] ?? 'Member',
          ),
        ),
      ),
      // Full-screen conversation pushed on the root navigator (same pattern
      // as /member/chat) so the trainer nav bar is hidden while chatting and
      // "<" pops back to the conversation list in the shell branch.
      GoRoute(
        path: '/trainer/chat/:roomId',
        pageBuilder: (_, state) => _iosPush(
          ChatRoomPage(roomId: state.pathParameters['roomId']!),
        ),
      ),
    ],
  );
});

class MemberShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const MemberShell({super.key, required this.navigationShell});

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> {
  void _onTap(int index) {
    // Nav tabs are fixed: 0 Home, 1 Workout, 2 In & Out (QR), 3 Food,
    // 4 Chat. QR (2) and Chat (4) are full-screen pushes (nav bar hidden);
    // the rest map onto shell branches — Food (3) is branch 2 because QR is
    // no longer a branch.
    switch (index) {
      case 2:
        context.push('/member/checkin');
        return;
      case 4:
        context.push('/member/chat');
        return;
      case 0:
      case 1:
      case 3:
        final branch = index == 3 ? 2 : index;
        widget.navigationShell.goBranch(
          branch,
          initialLocation: branch == widget.navigationShell.currentIndex,
        );
        return;
    }
  }

  /// Shell branch → nav-bar tab index for the active highlight. Home=0,
  /// Workout=1, Food=3 (QR=2 and Chat=4 are pushes, not branches).
  int get _activeTab {
    switch (widget.navigationShell.currentIndex) {
      case 2:
        return 3; // Food branch
      default:
        return widget.navigationShell.currentIndex; // Home / Workout
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent + extendBody so the page's glow background stays visible
      // behind/around the floating nav pill (no black band underneath).
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: MemberNavBar(
        currentIndex: _activeTab,
        onTap: _onTap,
      ),
    );
  }
}

class TrainerShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;
  const TrainerShell({super.key, required this.navigationShell});

  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  void _onTap(int index) {
    // Nav tabs are fixed: 0 Dashboard, 1 Members, 2 In & Out (QR), 3 Chat,
    // 4 Profile. QR (2) is a full-screen push (nav bar hidden); the rest map
    // onto shell branches — Chat (3) is branch 2 and Profile (4) is branch 3
    // because QR is no longer a branch.
    switch (index) {
      case 2:
        context.push('/trainer/checkin');
        return;
      case 0:
      case 1:
      case 3:
      case 4:
        final branch = index >= 3 ? index - 1 : index;
        widget.navigationShell.goBranch(
          branch,
          initialLocation: branch == widget.navigationShell.currentIndex,
        );
        return;
    }
  }

  /// Shell branch → nav-bar tab index for the active highlight. Dashboard=0,
  /// Members=1, Chat=3, Profile=4 (QR=2 is a push, not a branch).
  int get _activeTab {
    switch (widget.navigationShell.currentIndex) {
      case 2:
        return 3; // Chat branch
      case 3:
        return 4; // Profile branch
      default:
        return widget.navigationShell.currentIndex; // Dashboard / Members
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Transparent + extendBody so the page's glow background stays visible
      // behind/around the floating nav pill (no black band underneath).
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: TrainerNavBar(
        currentIndex: _activeTab,
        onTap: _onTap,
      ),
    );
  }
}
