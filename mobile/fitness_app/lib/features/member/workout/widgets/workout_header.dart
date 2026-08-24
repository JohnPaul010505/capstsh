import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/workout_session_provider.dart';
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
    final liveColor = isRunning ? const Color(0xFF30D158) : const Color(0xFF636366);
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
            color: liveColor.withAlpha(25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: liveColor.withAlpha(40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedPulseDot(
                color: isRunning ? const Color(0xFF30D158) : const Color(0xFF8E8E93),
                size: 6,
              ),
              const SizedBox(width: 5),
              Text(
                isRunning ? 'Live' : session.sessionEnded ? 'Done' : 'Ready',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: liveColor),
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