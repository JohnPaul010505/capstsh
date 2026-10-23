import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';

/// Timing and calories shared by the latest and saved session summaries.
class SessionMetrics extends StatelessWidget {
  const SessionMetrics({
    super.key,
    required this.elapsedSeconds,
    required this.restSeconds,
    required this.calories,
  });

  final int elapsedSeconds;
  final int restSeconds;
  final int calories;

  String _time(int seconds) => [
    seconds ~/ 3600,
    seconds ~/ 60 % 60,
    seconds % 60,
  ].map((part) => part.toString().padLeft(2, '0')).join(':');

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _metric('Session Duration', _time(elapsedSeconds), glassInk()),
      const SizedBox(width: 8),
      _metric('Break Time', _time(restSeconds), ClayTokens.clayPrimary),
      const SizedBox(width: 8),
      _metric('Total Calories', '$calories kcal', const Color(0xFFFF9F0A)),
    ],
  );

  Widget _metric(String label, String value, Color color) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF8E8E93)),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    ),
  );
}
