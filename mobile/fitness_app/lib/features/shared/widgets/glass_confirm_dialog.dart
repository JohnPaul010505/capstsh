import 'package:flutter/material.dart';
import 'glass_card.dart';
import '../../../app/design_tokens.dart';

Future<bool?> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Keep',
  Color? confirmColor,
}) => showDialog<bool>(
  context: context,
  builder: (dialogContext) => Dialog(
    backgroundColor: Colors.transparent,
    child: GlassPanel(
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ClayTokens.clayDarkTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: ClayTokens.clayDarkTextSecondary),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  style: FilledButton.styleFrom(
                    backgroundColor: ClayTokens.clayPrimary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(keepLabel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  style: FilledButton.styleFrom(
                    backgroundColor:
                        confirmColor ?? const Color(0xFFDC2626),
                    // Destructive confirms keep white text; a caller-supplied
                    // purple action flips to a dark label in light mode.
                    foregroundColor: confirmColor == null
                        ? Colors.white
                        : (ClayColors.isLightMode
                              ? ClayTokens.clayDarkSurface
                              : Colors.white),
                  ),
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  ),
);
