import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/pressable.dart';
import '../workout_constants.dart';

class WorkoutIdleOverlay extends ConsumerWidget {
  final WorkoutSessionState session;
  final WorkoutSessionNotifier notifier;

  const WorkoutIdleOverlay({
    super.key,
    required this.session,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!session.idleWarning) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: Colors.black.withAlpha(200),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1C1C2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2A2A45)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: ClayTokens.clayWarning.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.schedule, color: Color(0xFFFF9F0A), size: 26),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Are you still there?',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No activity for ${WorkoutConstants.idleTimeoutMinutes} minutes. The session will restart in ${session.idleWarningSeconds}s.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Color(0xFFB4B4D0)),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: PressableCard(
                          onTap: () => notifier.restartSession(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(12),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayError.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ClayTokens.clayError.withAlpha(100)),
                          ),
                          child: const Text(
                            'Restart',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFFF6B61)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: PressableCard(
                          onTap: () => notifier.continueFromIdle(),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          borderRadius: BorderRadius.circular(12),
                          decoration: BoxDecoration(
                            color: ClayTokens.clayAccent.withAlpha(25),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: ClayTokens.clayAccent.withAlpha(100)),
                          ),
                          child: const Text(
                            'Continue',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6EE7B7)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}