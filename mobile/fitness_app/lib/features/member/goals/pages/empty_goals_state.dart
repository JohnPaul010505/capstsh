import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:fitness_app/app/design_tokens.dart';
import '../../../shared/widgets/glass_card.dart';

const bgDark = Color(0xFF0B0D1A);
const cardDark = Color(0xFF15172A);
const inputDark = Color(0xFF1E2035);
const primaryPurple = Color(0xFF7C3AED);
const highlightPurple = Color(0xFFA855F7);
/// Inks for the empty-state body (dark ink on the light glass, near-white on
/// the dark one). The filled button below keeps pure white on its purple fill.
Color get textPrimary =>
    ClayColors.isLightMode ? ClayTokens.clayTextPrimary : const Color(0xFFFFFFFF);
Color get textSecondary => ClayColors.isLightMode
    ? ClayTokens.clayTextSecondary
    : const Color(0xFFA0A4B8);

class EmptyGoalsState extends StatelessWidget {
  final VoidCallback? onAction;

  const EmptyGoalsState({super.key, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520),
          child: MemberGlassCard(
            padding: const EdgeInsets.all(24),
            borderRadius: BorderRadius.circular(22),
            // Dark mode keeps its exact blurred panel.
            darkBuilder: (cardChild) => ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardDark.withAlpha(210),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: ClayTokens.hairline.withAlpha(28)),
                    boxShadow: [
                      BoxShadow(
                        color: primaryPurple.withAlpha(18),
                        blurRadius: 24,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: cardChild,
                ),
              ),
            ),
            child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: primaryPurple.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.flag,
                        color: primaryPurple,
                        size: 40,
                      ),
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
                      height: 52,
                      child: CupertinoButton.filled(
                        borderRadius: BorderRadius.circular(14),
                        onPressed: onAction,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.plus,
                              color: Color(0xFFFFFFFF),
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Create your first goal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
  }
}
