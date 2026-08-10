import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme.dart';

class FitnessApp extends ConsumerWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routerConfig = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'FitTrack',
      debugShowCheckedModeBanner: false,
      theme: clayThemeData,
      routerConfig: routerConfig,
      builder: (context, child) => DefaultTextStyle(
        // Safety net: guarantees no text anywhere ever inherits an
        // underline from an ambient theme default (yellow line under text).
        style: const TextStyle(decoration: TextDecoration.none),
        child: child!,
      ),
    );
  }
}
