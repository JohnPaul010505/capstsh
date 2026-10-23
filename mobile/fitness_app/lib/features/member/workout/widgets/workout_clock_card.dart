import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../providers/workout_session_provider.dart';
import '../../../shared/widgets/animations.dart';
import '../../../shared/widgets/glass_card.dart';

class WorkoutClockCard extends ConsumerWidget {
  final WorkoutSessionState session;
  final WorkoutSessionNotifier notifier;

  const WorkoutClockCard({
    super.key,
    required this.session,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = session.isRunning;
    final canStart =
        !isRunning && !session.sessionEnded && session.exercises.isNotEmpty;

    return MemberGlassCard(
      padding: const EdgeInsets.symmetric(vertical: 22),
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedPulseDot(
                color: isRunning
                    ? const Color(0xFF7C3AED)
                    : const Color(0xFF8E8E93),
                size: 6,
              ),
              const SizedBox(width: 6),
              Text(
                session.isPaused
                    ? 'REST BREAK'
                    : isRunning
                    ? 'SESSION ACTIVE'
                    : 'SESSION DURATION',
                style: TextStyle(
                  fontSize: 10,
                  color: isRunning && !session.isPaused
                      ? const Color(0xFF7C3AED)
                      : const Color(0xFF8E8E93),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _format(session.elapsedSeconds),
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              color: isRunning && !session.isPaused
                  ? const Color(0xFF7C3AED)
                  : ClayTokens.clayDarkTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            session.isPaused
                ? 'Rest time is included in the session duration'
                : isRunning
                ? 'Record proof then tap Done for each exercise'
                : session.exercises.isNotEmpty
                ? 'Ready to start — ${session.exercises.length} exercise${session.exercises.length == 1 ? '' : 's'}'
                : 'Add an exercise to begin',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              color: isRunning && !session.isPaused
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF8E8E93),
            ),
          ),
          if (isRunning) ...[
            const SizedBox(height: 10),
            Text(
              'Active ${_format(session.activeSeconds)}  ·  Rest ${_format(session.restSeconds)}',
              style: TextStyle(
                color: ClayTokens.clayDarkTextSecondary,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              // Paused → purple Resume Workout pill; live → blue Take a Break.
              // Same rounded shape/shadow as the Start Session pill so only the
              // accent color differs.
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: session.isPaused
                      ? const [Color(0xFF7C3AED), Color(0xFF7C3AED)]
                      : const [Color(0xFF7C3AED), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withAlpha(60),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: session.isPaused
                    ? notifier.resumeSession
                    : notifier.pauseSession,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: Icon(
                  session.isPaused ? Icons.play_arrow : Icons.pause,
                  size: 18,
                ),
                label: Text(
                  session.isPaused ? 'Resume Workout' : 'Take a Break',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (canStart) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withAlpha(60),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextButton.icon(
                onPressed: () => notifier.startSession(),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'Start Session',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
