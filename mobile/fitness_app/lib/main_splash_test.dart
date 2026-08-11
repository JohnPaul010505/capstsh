import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/member/onboarding/pages/onboarding_splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: MaterialApp(home: OnboardingSplashScreen())));
}
