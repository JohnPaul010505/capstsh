import 'package:flutter/material.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

class DateCard extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const DateCard({
    super.key,
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const monthNames = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final formattedDate = '${monthNames[date.month - 1]} ${date.day}, ${date.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: inputDark,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(10)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: primaryPurple,
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formattedDate,
              style: TextStyle(
                color: textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
