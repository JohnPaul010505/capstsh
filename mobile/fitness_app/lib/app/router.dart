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
import '../features/trainer/dashboard/pages/dashboard_page.dart' as trainer;
import '../features/trainer/progress/pages/progress_list_page.dart';
import '../features/trainer/progress/pages/member_progress_page.dart';
import '../features/trainer/chat/pages/chat_list_page.dart';
import '../features/trainer/chat/pages/chat_room_page.dart';
import '../features/trainer/profile/pages/profile_page.dart' as trainer_profile;
import '../features/shared/checkin/checkin_page.dart';
import '../features/shared/widgets/member_nav_bar.dart';
import 'package:circle_nav_bar/circle_nav_bar.dart';

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

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final profile = authState.valueOrNull;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) {
        if (profile?.role == 'trainer') return '/trainer/dashboard';
        return '/member/home';
      }
      if (isLoggedIn && profile != null) {
        final loc = state.matchedLocation;
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
          GoRoute(path: '/trainer/checkin', pageBuilder: (_, __) => _iosPush(const CheckinPage())),
          GoRoute(path: '/trainer/chat', pageBuilder: (_, __) => _iosPush(const ChatListPage())),
          GoRoute(path: '/trainer/chat/:roomId', pageBuilder: (_, state) => _iosPush(ChatRoomPage(roomId: state.pathParameters['roomId']!))),
          GoRoute(path: '/trainer/profile', pageBuilder: (_, __) => _iosPush(const trainer_profile.ProfilePage())),
        ],
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
    if (location.startsWith('/trainer/chat')) return 2;
    if (location.startsWith('/trainer/profile')) return 3;
    return 0;
  }

  void _onTap(int index) {
    setState(() => _currentIndex = index);
    switch (index) {
      case 0: context.go('/trainer/dashboard');
      case 1: context.go('/trainer/members');
      case 2: context.go('/trainer/chat');
      case 3: context.go('/trainer/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: CircleNavBar(
        activeIcons: const [
          Icon(Icons.dashboard, color: Colors.white),
          Icon(Icons.people, color: Colors.white),
          Icon(Icons.message, color: Colors.white),
          Icon(Icons.person, color: Colors.white),
        ],
        inactiveIcons: const [
          Icon(Icons.dashboard, color: Colors.white38),
          Icon(Icons.people, color: Colors.white38),
          Icon(Icons.message, color: Colors.white38),
          Icon(Icons.person, color: Colors.white38),
        ],
        color: const Color(0xFF1C1C35),
        circleColor: const Color(0xFF7C3AED),
        height: 60,
        circleWidth: 56,
        activeIndex: _currentIndex,
        onTap: _onTap,
        tabCurve: Curves.easeOutCubic,
        iconCurve: Curves.easeOutBack,
        tabDurationMillSec: 500,
        iconDurationMillSec: 450,
        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
        cornerRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        shadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.3),
        circleShadowColor: const Color(0xFF7C3AED).withValues(alpha: 0.4),
        elevation: 8,
      ),
    );
  }
}
