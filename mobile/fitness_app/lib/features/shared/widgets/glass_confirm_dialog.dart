import 'package:flutter/material.dart';
import 'glass_card.dart';
import '../../../app/design_tokens.dart';

Future<bool?> showGlassConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String keepLabel = 'Keep',
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
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
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
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
