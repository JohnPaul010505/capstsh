import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../app/design_tokens.dart';

class TrainerNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const TrainerNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _raise = 27.0;

  static const _tabs = <({IconData inactive, IconData active, String label})>[
    (inactive: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Dashboard'),
    (inactive: Icons.people_outlined, active: Icons.people, label: 'Members'),
    (inactive: Icons.qr_code_scanner_outlined, active: Icons.qr_code_scanner, label: 'In & Out'),
    (inactive: Icons.chat_bubble_outline, active: Icons.chat, label: 'Chat'),
    (inactive: Icons.person_outlined, active: Icons.person, label: 'Profile'),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: barH,
                decoration: BoxDecoration(
                  color: ClayTokens.clayPrimaryLight.withAlpha(25),
                  borderRadius: BorderRadius.circular(40),
                  border: Border.all(color: Colors.white.withAlpha(18)),
                ),
                child: Row(
                  children: List.generate(_tabs.length, (i) {
                    if (i == 2) {
                      // Center slot: text only for "In & Out"
                      return Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(2),
                          child: Padding(
                            padding: EdgeInsets.only(top: circleD - 21),
                            child: Text(
                              _tabs[i].label,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.dmSans(
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
                              color: isActive ? purple : ClayTokens.clayDarkTextTertiary,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _tabs[i].label,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                color: isActive ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayDarkTextTertiary,
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
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Icon(
                      currentIndex == 2 ? Icons.qr_code_scanner : Icons.qr_code_scanner_outlined,
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