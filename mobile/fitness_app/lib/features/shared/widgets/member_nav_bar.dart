import 'package:flutter/material.dart';
import '../../../app/design_tokens.dart';

class MemberNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const MemberNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _raise = 24.4;

  static const _tabs = <({IconData inactive, IconData active, String label})>[
    (inactive: Icons.home_outlined, active: Icons.home, label: 'Home'),
    (
      inactive: Icons.fitness_center,
      active: Icons.fitness_center,
      label: 'Workout',
    ),
    (
      inactive: Icons.qr_code_scanner,
      active: Icons.qr_code_scanner,
      label: 'In & Out',
    ),
    (inactive: Icons.restaurant, active: Icons.restaurant, label: 'Food'),
    (
      inactive: Icons.chat_bubble_outline,
      active: Icons.chat_bubble,
      label: 'Chat',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    const barH = 62.0;
    const circleD = 58.0;
    final purple = ClayTokens.clayPrimary;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 8),
      child: SizedBox(
        height: barH + _raise,
        child: Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Bar body
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: barH,
                decoration: BoxDecoration(
                  color: ClayTokens.clayDarkSurface,
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(
                    color: ClayTokens.clayDarkBorder.withValues(
                      alpha: 100 / 255,
                    ),
                    width: 0.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: purple.withValues(alpha: 0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    if (i == 2) {
                      // Center slot: label under raised button, reserved space
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(2),
                          child: Padding(
                            padding: EdgeInsets.only(top: circleD - 18),
                            child: Text(
                              _tabs[i].label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: ClayTokens.clayDarkTextSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final isActive = i == currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => onTap(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? _tabs[i].active : _tabs[i].inactive,
                              size: 24,
                              color: isActive
                                  ? purple
                                  : ClayTokens.clayDarkTextTertiary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tabs[i].label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isActive
                                    ? ClayTokens.clayDarkTextPrimary
                                    : ClayTokens.clayDarkTextTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            // Raised center button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: circleD,
                    height: circleD,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [purple, ClayTokens.clayPrimaryLight],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: purple.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                      border: Border.all(
                        color: ClayTokens.clayDarkSurface,
                        width: 4,
                      ),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
