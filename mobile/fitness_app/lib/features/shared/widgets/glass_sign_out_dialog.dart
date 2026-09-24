import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../../app/design_tokens.dart';

/// Glassmorphic sign-out confirmation shared by member Settings
/// and trainer Profile. Returns true when the user taps Yes.
Future<bool> showGlassSignOutDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: 320,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            decoration: BoxDecoration(
              color: ClayTokens.clayDarkSurface.withAlpha(208),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withAlpha(30)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(90),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Are you sure you want to sign out?',
                  style: TextStyle(
                    color: ClayTokens.clayDarkTextSecondary,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _GlassDialogButton(
                        label: 'No',
                        backgroundColor: ClayTokens.clayPrimary,
                        onPressed: () => Navigator.of(ctx).pop(false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _GlassDialogButton(
                        label: 'Yes',
                        backgroundColor: ClayTokens.clayError,
                        onPressed: () => Navigator.of(ctx).pop(true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  return result ?? false;
}

class _GlassDialogButton extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _GlassDialogButton({
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }
}
