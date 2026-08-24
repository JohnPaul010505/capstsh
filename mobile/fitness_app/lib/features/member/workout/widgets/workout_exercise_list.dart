import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../widgets/exercise_proof_button.dart';

class WorkoutExerciseList extends ConsumerWidget {
  final WorkoutSessionState session;
  final WorkoutSessionNotifier notifier;

  const WorkoutExerciseList({
    super.key,
    required this.session,
    required this.notifier,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.exercises.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'No exercises yet — search above to add one',
            style: TextStyle(color: Color(0xFF636366), fontSize: 12),
          ),
        ),
      );
    }

    final currentIndex = session.exercises.indexWhere((e) => !e.isDone);

    return Column(
      children: [
        ...session.exercises.asMap().entries.map(
          (entry) {
            final i = entry.key;
            final e = entry.value;
            final isCurrent = i == currentIndex;
            final isDone = e.isDone;
            return _ExerciseCard(
              exercise: e,
              index: i,
              isCurrent: isCurrent,
              isDone: isDone,
              isRunning: session.isRunning,
              sessionStartedAt: session.startedAt,
              weightKg: session.weightKg,
              canStartProof: session.isRunning && isCurrent,
              onProofRecorded: (url) => notifier.markProofRecorded(i, url),
              onProofRemoved: () => notifier.removeProof(i),
              onDone: () => notifier.markDone(i),
              onRemove: () => notifier.removeExercise(i),
            );
          },
        ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final SessionExercise exercise;
  final int index;
  final bool isCurrent;
  final bool isDone;
  final bool isRunning;
  final DateTime? sessionStartedAt;
  final double weightKg;
  final bool canStartProof;
  final ValueChanged<String> onProofRecorded;
  final VoidCallback onProofRemoved;
  final VoidCallback onDone;
  final VoidCallback onRemove;

  const _ExerciseCard({
    required this.exercise,
    required this.index,
    required this.isCurrent,
    required this.isDone,
    required this.isRunning,
    required this.sessionStartedAt,
    required this.weightKg,
    required this.canStartProof,
    required this.onProofRecorded,
    required this.onProofRemoved,
    required this.onDone,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise.name;
    final hasVideo = exercise.hasProof;
    final duration = exercise.isDone
        ? _fmt(exercise.doneAt!.difference(exercise.startedAt ?? sessionStartedAt ?? exercise.doneAt!).inSeconds)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF1C1C2E) : ClayTokens.clayDarkSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent ? const Color(0xFFA78BFA).withAlpha(80) : const Color(0xFF2A2A45),
            width: isCurrent ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isDone
                        ? ClayTokens.clayAccent.withAlpha(25)
                        : isCurrent
                            ? const Color(0xFFBF5AF2).withAlpha(25)
                            : const Color(0xFF636366).withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isDone ? Icons.check : isCurrent ? Icons.play_arrow : Icons.schedule,
                    color: isDone
                        ? ClayTokens.clayAccent
                        : isCurrent
                            ? const Color(0xFFD6A5FF)
                            : const Color(0xFF8E8E93),
                    size: 14,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
                      ),
                      Text(
                        '${exercise.category} · MET ${exercise.met}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
                      ),
                    ],
                  ),
                ),
                if (isDone) ...[
                  Text(
                    duration ?? '',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD6A5FF)),
                  ),
                ],
              ],
            ),
            if (canStartProof) ...[
              const SizedBox(height: 8),
              ExerciseProofTile(
                videoUrl: exercise.proofUrl,
                onRecorded: onProofRecorded,
                onRemoved: onProofRemoved,
                onDone: onDone,
              ),
              const SizedBox(height: 8),
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
                  onPressed: hasVideo ? onDone : null,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    disabledForegroundColor: Colors.white.withAlpha(120),
                  ),
                  child: Text(
                    hasVideo ? 'Done — Timestamp Now' : 'Record proof to unlock Done',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ] else if (!isDone && !isRunning) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Text(
                        'Remove',
                        style: TextStyle(fontSize: 11, color: Color(0xFFFF6B61)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _fmt(int s) {
    final m = s ~/ 60;
    final sec = s % 60;
    return m > 0 ? '${m}m ${sec}s' : '${sec}s';
  }
}