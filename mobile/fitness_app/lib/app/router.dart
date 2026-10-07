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
import '../features/trainer/progress/pages/member_progress_page.dart';
import '../features/trainer/chat/pages/chat_list_page.dart';
import '../features/trainer/chat/pages/chat_room_page.dart';
import '../features/trainer/profile/pages/profile_page.dart' as trainer_profile;
import '../features/trainer/feedback/pages/give_feedback_page.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/create_plan_screen.dart';
import 'package:fitness_app/features/trainer/set_plan/pages/record_screen.dart';
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
                path: '/member/checkin',
                pageBuilder: (_, __) => _iosPush(
                  const CheckinPage(
                    showBack: false,
                    returnRoute: '/member/home',
                  ),
                ),
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
                routes: [
                  GoRoute(
                    path: ':id',
                    pageBuilder: (_, state) => _iosPush(
                      MemberProgressPage(id: state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/checkin',
                pageBuilder: (_, __) => _iosPush(
                  const CheckinPage(
                    showBack: false,
                    returnRoute: '/trainer/dashboard',
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/trainer/chat',
                pageBuilder: (_, __) => _iosPush(const ChatListPage()),
                routes: [
                  GoRoute(
                    path: ':roomId',
                    pageBuilder: (_, state) => _iosPush(ChatRoomPage(
                        roomId: state.pathParameters['roomId']!)),
                  ),
                ],
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
    // Chat (index 4) is a full-screen pushed route, not a shell branch:
    // the nav bar disappears and "<" on the chat header pops back here.
    if (index == 4) {
      context.push('/member/chat');
      return;
    }
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
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
        currentIndex: widget.navigationShell.currentIndex,
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
    // Detail/room pages live INSIDE their branch, so the nav bar stays and
    // the branch keeps its scroll position; tapping the active tab pops back
    // to the branch root (e.g. room list).
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
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
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
