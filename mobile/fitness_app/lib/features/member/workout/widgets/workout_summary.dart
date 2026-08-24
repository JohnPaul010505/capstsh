import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';
import '../workout_constants.dart';
import '../../../shared/widgets/proof_video_viewer.dart';

class WorkoutSummary extends ConsumerWidget {
  final WorkoutSessionState session;
  final WorkoutSessionNotifier notifier;
  final bool showPrevCards;
  final VoidCallback onShowPrevCards;
  final VoidCallback onInvalidateProviders;

  const WorkoutSummary({
    super.key,
    required this.session,
    required this.notifier,
    required this.showPrevCards,
    required this.onShowPrevCards,
    required this.onInvalidateProviders,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return StaggeredFadeIn(
      index: 99,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2A2A45)),
          gradient: RadialGradient(
            center: const Alignment(0.9, -0.9),
            radius: 1.2,
            colors: [
              const Color(0xFF7C3AED).withAlpha(60),
              const Color(0xFF1C1C2E),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Workout Complete',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayAccent.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'SESSION DONE',
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: ClayTokens.clayAccentLight),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            if (session.sessionCount <= 2)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.emoji_events_outlined, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Congratulations for Completing Workout',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 3),
            const Text(
              "Great job! Here's your session summary.",
              style: TextStyle(fontSize: 10, color: Color(0xFFB4B4D0)),
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: const Color(0xFF2A2A45)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withAlpha(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16, color: Color(0xFFD6A5FF)),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Session Duration', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        _format(session.elapsedSeconds),
                        style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Total Calories', style: TextStyle(
                        fontSize: 10, color: Color(0xFF8E8E93),
                      )),
                      Text(
                        '${session.latestCalories} kcal',
                        style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFFF9F0A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...session.exercises.map((e) {
              final name = e.name;
              final duration = _formatDuration(e.startedAt, e.doneAt);
              final hasVideo = e.hasProof;
              final kcal = session.caloriesFor(e, session.weightKg);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withAlpha(10)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 20, height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: hasVideo
                                  ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)])
                                  : null,
                              color: hasVideo ? null : const Color(0xFF3A3A4A),
                            ),
                            child: Icon(
                              hasVideo ? Icons.check : Icons.close,
                              size: 12,
                              color: hasVideo ? Colors.white : const Color(0xFF8E8E93),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(name, style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFF2F5F7),
                            )),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _summaryStat(icon: Icons.timer_outlined, value: duration, color: const Color(0xFFD6A5FF)),
                          const SizedBox(width: 12),
                          _summaryStat(icon: Icons.local_fire_department_outlined, value: '${kcal.round()} kcal', color: const Color(0xFFFF9F0A)),
                          const Spacer(),
                          if (hasVideo)
                            GestureDetector(
                              onTap: () => showProofVideoDialog(context, e.proofUrl!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF7C3AED).withAlpha(50),
                                      const Color(0xFFC56BF0).withAlpha(30),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF7C3AED).withAlpha(100)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.play_circle_outline, size: 12, color: Color(0xFFD6A5FF)),
                                    SizedBox(width: 3),
                                    Text('View', style: TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFD6A5FF),
                                    )),
                                  ],
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF453A).withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('No proof', style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFFFF6B61),
                              )),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 12),
            if (session.completedSessions.length > 1 && !showPrevCards)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: onShowPrevCards,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    session.completedSessions.length >= 3 ? 'View All Sessions' : 'View Workout S1',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            if (session.completedSessions.length > 1 && session.completedSessionCount < WorkoutConstants.minSessionsPerDay && !showPrevCards)
              const SizedBox(height: 8),
            if (session.completedSessionCount < WorkoutConstants.minSessionsPerDay)
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF5E3AEE), Color(0xFFC56BF0)]),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC56BF0).withAlpha(60),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextButton(
                  onPressed: () {
                    onInvalidateProviders();
                    notifier.restartSession();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text(
                    'New Session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _format(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return '—';
    final s = end.difference(start).inSeconds;
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }

  Widget _summaryStat({required IconData icon, required String value, required Color color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: color,
        )),
      ],
    );
}
}