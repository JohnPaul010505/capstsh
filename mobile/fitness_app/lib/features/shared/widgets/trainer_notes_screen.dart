import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import 'app_glow_background.dart';
import 'glass_card.dart';

/// Opens the trainer's notes as a dedicated FULL-SCREEN glass page.
///
/// Pushed on the ROOT navigator so it covers the member nav bar entirely —
/// the same trick the proof recorder uses. The old inline note sat in a bottom
/// sheet, which left the nav bar visible and tappable underneath.
Future<void> openTrainerNotesScreen(
  BuildContext context, {
  required String? notes,
  required String dayLabel,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TrainerNotesScreen(notes: notes, dayLabel: dayLabel),
    ),
  );
}

/// Read-only screen for the trainer's written recommendation ("notes").
/// Glass surfaces, no nav bar, a single X to close.
class TrainerNotesScreen extends StatelessWidget {
  final String? notes;
  final String dayLabel;

  const TrainerNotesScreen({
    super.key,
    required this.notes,
    required this.dayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final body = (notes ?? '').trim();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: ClayTokens.clayDarkBase,
      body: AppGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Centred header with X on the right — same grammar as the sheets.
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Text(
                        'Trainer Notes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: ClayTokens.clayDarkTextPrimary,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close,
                            color: ClayTokens.clayDarkTextSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: ClayTokens.clayDarkDivider, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ClayTokens.clayPrimary.withAlpha(38),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ClayTokens.clayPrimaryLight,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (body.isEmpty)
                      GlassPanel(
                        child: Row(
                          children: [
                            Icon(Icons.sticky_note_2_outlined,
                                color: ClayTokens.clayDarkTextTertiary,
                                size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Your trainer has not written any notes for '
                                'this day yet.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.45,
                                  color: ClayTokens.clayDarkTextSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      GlassPanel(
                        child: Text(
                          body,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.55,
                            color: ClayTokens.clayDarkTextPrimary,
                          ),
                        ),
                      ),
                    SizedBox(height: bottomPadding + 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
