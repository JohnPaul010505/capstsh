import 'package:flutter/cupertino.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
const textPrimary = Color(0xFFFFFFFF);
const textSecondary = Color(0xFFA0A4B8);

class EmptyGoalsState extends StatelessWidget {
  final VoidCallback? onAction;

  const EmptyGoalsState({super.key, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: cardDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryPurple.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: primaryPurple.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: Icon(CupertinoIcons.flag, color: primaryPurple, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              'No Goals Yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create your first fitness goal and start your journey today!',
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: CupertinoButton(
                color: primaryPurple,
                borderRadius: BorderRadius.circular(12),
                onPressed: onAction,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(CupertinoIcons.plus, color: textPrimary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Create Your First Goal',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
