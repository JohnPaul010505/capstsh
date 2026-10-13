import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared/providers/auth_provider.dart';
import '../features/member/goals/services/goal_home_widget.dart';
import 'router.dart';
import 'theme_mode_provider.dart';
import 'theme.dart';

class FitnessApp extends ConsumerStatefulWidget {
  const FitnessApp({super.key});

  @override
  ConsumerState<FitnessApp> createState() => _FitnessAppState();
}

class _FitnessAppState extends ConsumerState<FitnessApp> {
  StreamSubscription<Uri?>? _widgetClickSubscription;
  bool _pendingGoalsRoute = false;

  @override
  void initState() {
    super.initState();
    _widgetClickSubscription = HomeWidget.widgetClicked.listen(
      _openGoalsFromWidget,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final initialUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      await _openGoalsFromWidget(initialUri);
    });
  }

  Future<void> _openGoalsFromWidget(Uri? uri) async {
    if (uri?.path != '/member/goals') return;
    _pendingGoalsRoute = true;
    final profile = ref.read(authProvider).valueOrNull;
    if (profile?.role == 'member') _navigateToGoals();
  }

  @override
  void dispose() {
    _widgetClickSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (previous, next) {
      if (next.hasValue && next.valueOrNull?.role != 'member') {
        GoalHomeWidget.clear();
      }
      final profile = next.valueOrNull;
      if (_pendingGoalsRoute && profile != null) {
        if (profile.role == 'member') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _navigateToGoals();
          });
        } else {
          _pendingGoalsRoute = false;
        }
      }
    });
    final routerConfig = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'FitTrack',
      debugShowCheckedModeBanner: false,
      theme: clayLightThemeData,
      darkTheme: clayThemeData,
      themeMode: themeMode,
      routerConfig: routerConfig,
      builder: (context, child) => DefaultTextStyle(
        style: const TextStyle(decoration: TextDecoration.none),
        child: child!,
      ),
    );
  }

  void _navigateToGoals() {
    _pendingGoalsRoute = false;
    if (mounted) ref.read(routerProvider).go('/member/goals');
  }
}
