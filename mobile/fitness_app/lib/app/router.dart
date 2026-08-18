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
import '../features/shared/checkin/checkin_page.dart';
import '../features/shared/widgets/member_nav_bar.dart';
import '../features/member/onboarding/pages/onboarding_splash_screen.dart';
import '../features/shared/widgets/trainer_nav_bar.dart';

final _trainerShellKey = GlobalKey<NavigatorState>();

Page<dynamic> _iosPush(Widget child) => CustomTransitionPage(
  child: child,
  transitionsBuilder: (_, animation, __, child) {
    final scale = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
    final fade = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
    );
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
  final needsOnboarding = ref.read(needsOnboardingSyncProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
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
        if (needsOnboarding && loc != '/member/onboarding') return '/member/onboarding';
        if (profile.role == 'member' && loc.startsWith('/trainer')) return '/member/home';
        if (profile.role == 'member' && loc.startsWith('/admin')) return '/member/home';
        if (profile.role == 'trainer' && loc.startsWith('/member')) return '/trainer/dashboard';
        if (profile.role == 'trainer' && loc.startsWith('/admin')) return '/trainer/dashboard';
        if (profile.role == 'admin') return '/member/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', pageBuilder: (_, __) => _iosPush(const LoginPage())),
      GoRoute(
        path: '/member/onboarding',
        pageBuilder: (_, __) => _iosPush(const OnboardingSplashScreen()),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MemberShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/home', pageBuilder: (_, __) => _iosPush(const HomePage())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/workout', pageBuilder: (_, __) => _iosPush(const WorkoutPage())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/checkin', pageBuilder: (_, __) => _iosPush(const CheckinPage(showBack: false))),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/meals', pageBuilder: (_, __) => _iosPush(const MealLogPage())),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/member/chat', pageBuilder: (_, __) => _iosPush(const ChatPage())),
          ]),
        ],
      ),
      GoRoute(path: '/member/settings', pageBuilder: (_, __) => _iosPush(const SettingsPage())),
      GoRoute(path: '/member/goals', pageBuilder: (_, __) => _iosPush(const GoalsPage())),
      GoRoute(path: '/member/feedback', pageBuilder: (_, __) => _iosPush(const FeedbackPage())),
      GoRoute(path: '/member/bmi', pageBuilder: (_, __) => _iosPush(const BmiPage())),
      GoRoute(path: '/member/notifications', pageBuilder: (_, __) => _iosPush(const NotificationsPage())),
      ShellRoute(
        navigatorKey: _trainerShellKey,
        builder: (_, __, child) => TrainerShell(child: child),
        routes: [
          GoRoute(path: '/trainer/dashboard', pageBuilder: (_, __) => _iosPush(const trainer.DashboardPage())),
          GoRoute(
            path: '/trainer/members',
            pageBuilder: (_, __) => _iosPush(const ProgressListPage()),
            routes: [
              GoRoute(path: ':id', pageBuilder: (_, state) => _iosPush(MemberProgressPage(id: state.pathParameters['id']!))),
            ],
          ),
          GoRoute(path: '/trainer/checkin', pageBuilder: (_, __) => _iosPush(const CheckinPage(showBack: false))),
          GoRoute(path: '/trainer/chat', pageBuilder: (_, __) => _iosPush(const ChatListPage())),
          GoRoute(path: '/trainer/chat/:roomId', pageBuilder: (_, state) => _iosPush(ChatRoomPage(roomId: state.pathParameters['roomId']!))),
          GoRoute(path: '/trainer/profile', pageBuilder: (_, __) => _iosPush(const trainer_profile.ProfilePage())),
        ],
      ),
      GoRoute(path: '/trainer/notifications', pageBuilder: (_, __) => _iosPush(const TrainerNotificationsPage())),
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
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: MemberNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _onTap,
      ),
    );
  }
}

class TrainerShell extends StatefulWidget {
  final Widget child;
  const TrainerShell({super.key, required this.child});

  @override
  State<TrainerShell> createState() => _TrainerShellState();
}

class _TrainerShellState extends State<TrainerShell> {
  int _currentIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _currentIndex = _trainerIndex();
  }

  @override
  void didUpdateWidget(covariant TrainerShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _currentIndex = _trainerIndex();
  }

  int _trainerIndex() {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/trainer/members')) return 1;
    if (location.startsWith('/trainer/chat')) return 3;
    if (location.startsWith('/trainer/profile')) return 4;
    if (location.startsWith('/trainer/checkin')) return 2;
    return 0;
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0: context.go('/trainer/dashboard');
      case 1: context.go('/trainer/members');
      case 2: context.go('/trainer/checkin');
      case 3: context.go('/trainer/chat');
      case 4: context.go('/trainer/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: TrainerNavBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
      ),
    );
  }
}
