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

  static const _tabs = <({IconData inactive, IconData active, String label})>[
    (inactive: Icons.dashboard_outlined, active: Icons.dashboard, label: 'Dashboard'),
    (inactive: Icons.people_outlined, active: Icons.people, label: 'Members'),
    (inactive: Icons.message_outlined, active: Icons.message, label: 'Chat'),
    (inactive: Icons.person_outlined, active: Icons.person, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    const barH = 62.0;
    final purple = ClayTokens.clayPrimary;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 8),
      child: SizedBox(
        height: barH,
        child: Container(
          decoration: BoxDecoration(
            color: ClayTokens.clayPrimaryLight.withAlpha(25),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withAlpha(18)),
          ),
          child: Row(
            children: List.generate(_tabs.length, (i) {
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
                        style: GoogleFonts.dmSans(
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
    );
  }
}