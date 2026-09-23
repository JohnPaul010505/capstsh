import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/animations.dart';

class WorkoutHeader extends ConsumerWidget {
  final WorkoutSessionState session;
  final VoidCallback onDateTap;

  const WorkoutHeader({
    super.key,
    required this.session,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isRunning = session.isRunning;
    final isDone = session.sessionEnded;
    final label = isRunning ? 'Live' : isDone ? 'Done' : 'Ready';
    // Ready = purple · Live = red · Done = green (all with readable text).
    final Color chipBg;
    final Color chipFg;
    if (isRunning) {
      chipBg = const Color(0xFFEF4444); // red — live workout
      chipFg = Colors.white;
    } else if (isDone) {
      chipBg = const Color(0xFF30D158); // green — workout finished
      chipFg = const Color(0xFF052E16); // dark text stays readable on green
    } else {
      chipBg = ClayTokens.clayPrimary; // purple — not started yet
      chipFg = Colors.white;
    }
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'WORKOUT LOG',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: Color(0xFFFFFFFF)),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: chipBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: chipFg.withAlpha(70)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedPulseDot(color: chipFg, size: 6),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: chipFg),
              ),
            ],
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: onDateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF7C3AED), Color(0xFFC56BF0)],
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  DateFormat('MMM d').format(DateTime.now()),
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}