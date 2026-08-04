import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../../../../app/design_tokens.dart';

enum ClayButtonStyle { primary, secondary, ghost, destructive }

enum ClayButtonSize { small, medium, large }

class ClayButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final ClayButtonStyle style;
  final ClayButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;
  final bool fullWidth;
  final EdgeInsetsGeometry? padding;
  final bool enabled;

  const ClayButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.style = ClayButtonStyle.primary,
    this.size = ClayButtonSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
    this.fullWidth = false,
    this.padding,
    this.enabled = true,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ClayTokens.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _pressController, curve: ClayTokens.spring),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (!widget.enabled || widget.loading || widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _pressController.forward();
    Haptics.vibrate(HapticsType.light);
  }

  void _handleTapUp(TapUpDetails _) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  Color _getBackgroundColor(bool isDark) {
    switch (widget.style) {
      case ClayButtonStyle.primary:
        return ClayTokens.clayPrimary;
      case ClayButtonStyle.secondary:
        return isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated;
      case ClayButtonStyle.ghost:
        return Colors.transparent;
      case ClayButtonStyle.destructive:
        return ClayTokens.clayError;
    }
  }

  Color _getTextColor(bool isDark) {
    switch (widget.style) {
      case ClayButtonStyle.primary:
      case ClayButtonStyle.destructive:
        return ClayTokens.clayTextOnPrimary;
      case ClayButtonStyle.secondary:
        return isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary;
      case ClayButtonStyle.ghost:
        return isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary;
    }
  }

  Color _getBorderColor(bool isDark) {
    if (widget.style == ClayButtonStyle.secondary) {
      return isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder;
    }
    if (widget.style == ClayButtonStyle.ghost) {
      return isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder;
    }
    return Colors.transparent;
  }

  List<BoxShadow> _getShadows(bool isDark, bool isPressed) {
    if (widget.style == ClayButtonStyle.ghost) return [];

    if (isDark) {
      if (isPressed) return ClayTokens.darkLevel0;
      return widget.style == ClayButtonStyle.primary ? ClayTokens.darkLevel2 : ClayTokens.darkLevel1;
    }

    if (isPressed) return ClayTokens.level0;
    return widget.style == ClayButtonStyle.primary ? ClayTokens.level2 : ClayTokens.level1;
  }

  EdgeInsetsGeometry _getPadding() {
    final horizontal = widget.size == ClayButtonSize.small ? ClayTokens.lg :
        widget.size == ClayButtonSize.medium ? ClayTokens.xl : ClayTokens.xxl;
    final vertical = ClayTokens.md;
    return widget.padding ?? EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  double _getFontSize() {
    return widget.size == ClayButtonSize.small ? 13 :
        widget.size == ClayButtonSize.medium ? 15 : 17;
  }

  double _getIconSize() {
    return widget.size == ClayButtonSize.small ? 16 :
        widget.size == ClayButtonSize.medium ? 18 : 20;
  }

  double _getHeight() {
    return widget.size == ClayButtonSize.small ? 50 :
        widget.size == ClayButtonSize.medium ? 52 : 56;
  }

  double _getRadius() {
    return ClayTokens.radiusButton;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.enabled && widget.onPressed != null && !widget.loading;

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.loading || !enabled ? null : () {
              Haptics.vibrate(HapticsType.light);
              widget.onPressed?.call();
            },
            child: AnimatedContainer(
              duration: ClayTokens.fast,
              curve: ClayTokens.easeOut,
              width: widget.fullWidth ? double.infinity : widget.width,
              height: _getHeight(),
              padding: _getPadding(),
              decoration: BoxDecoration(
                color: enabled ? _getBackgroundColor(isDark) : _getBackgroundColor(isDark).withAlpha(100),
                borderRadius: BorderRadius.circular(_getRadius()),
                border: Border.all(
                  color: _getBorderColor(isDark),
                  width: widget.style == ClayButtonStyle.ghost ? 1.5 : 0,
                ),
                boxShadow: enabled ? _getShadows(isDark, _isPressed) : [],
              ),
              child: widget.loading
                  ? Center(
                      child: SizedBox(
                        width: _getIconSize(),
                        height: _getIconSize(),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(_getTextColor(isDark)),
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(widget.leadingIcon, size: _getIconSize(), color: _getTextColor(isDark)),
                          SizedBox(width: ClayTokens.sm),
                        ],
                        Text(
                          widget.label,
                          style: GoogleFonts.dmSans(
                            fontSize: _getFontSize(),
                            fontWeight: FontWeight.w600,
                            color: enabled ? _getTextColor(isDark) : _getTextColor(isDark).withAlpha(100),
                            letterSpacing: 0.2,
                          ),
                        ),
                        if (widget.trailingIcon != null) ...[
                          SizedBox(width: ClayTokens.sm),
                          Icon(widget.trailingIcon, size: _getIconSize(), color: _getTextColor(isDark)),
                        ],
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Specialized button variants for common use cases
class ClayPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;
  final ClayButtonSize size;

  const ClayPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
    this.size = ClayButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      style: ClayButtonStyle.primary,
      size: size,
      leadingIcon: icon,
      fullWidth: fullWidth,
    );
  }
}

class ClaySecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;
  final ClayButtonSize size;

  const ClaySecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
    this.size = ClayButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      style: ClayButtonStyle.secondary,
      size: size,
      leadingIcon: icon,
      fullWidth: fullWidth,
    );
  }
}

class ClayGhostButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;
  final ClayButtonSize size;

  const ClayGhostButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
    this.size = ClayButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      style: ClayButtonStyle.ghost,
      size: size,
      leadingIcon: icon,
      fullWidth: fullWidth,
    );
  }
}

class ClayDestructiveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool fullWidth;
  final ClayButtonSize size;

  const ClayDestructiveButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.fullWidth = false,
    this.size = ClayButtonSize.medium,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      label: label,
      onPressed: onPressed,
      loading: loading,
      style: ClayButtonStyle.destructive,
      size: size,
      leadingIcon: icon,
      fullWidth: fullWidth,
    );
  }
}

/// Icon-only button (circular)
class ClayIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final ClayButtonStyle style;
  final double size;
  final Color? customColor;

  const ClayIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.loading = false,
    this.style = ClayButtonStyle.primary,
    this.size = 48,
    this.customColor,
  });

  @override
  State<ClayIconButton> createState() => _ClayIconButtonState();
}

class _ClayIconButtonState extends State<ClayIconButton> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ClayTokens.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _pressController, curve: ClayTokens.spring),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.loading || widget.onPressed == null) return;
    setState(() => _isPressed = true);
    _pressController.forward();
    Haptics.vibrate(HapticsType.light);
  }

  void _handleTapUp(_) {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  void _handleTapCancel() {
    if (!_isPressed) return;
    setState(() => _isPressed = false);
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = widget.onPressed != null && !widget.loading;

    Color bgColor;
    Color iconColor;
    List<BoxShadow> shadows = [];

    if (widget.style == ClayButtonStyle.primary) {
      bgColor = widget.customColor ?? ClayTokens.clayPrimary;
      iconColor = ClayTokens.clayTextOnPrimary;
      shadows = ClayTokens.level1;
    } else if (widget.style == ClayButtonStyle.secondary) {
      bgColor = isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated;
      iconColor = isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary;
      shadows = ClayTokens.level0;
    } else if (widget.style == ClayButtonStyle.ghost) {
      bgColor = Colors.transparent;
      iconColor = isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary;
    } else {
      bgColor = ClayTokens.clayError;
      iconColor = ClayTokens.clayTextOnPrimary;
      shadows = ClayTokens.level1;
    }

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnimation.value,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: widget.loading || !enabled ? null : () {
            Haptics.vibrate(HapticsType.light);
            widget.onPressed?.call();
          },
          child: AnimatedContainer(
            duration: ClayTokens.fast,
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: enabled ? bgColor : bgColor.withAlpha(100),
              shape: BoxShape.circle,
              boxShadow: enabled && _isPressed ? [] : shadows,
              border: widget.style == ClayButtonStyle.ghost
                  ? Border.all(color: isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder, width: 1.5)
                  : null,
            ),
            child: widget.loading
                ? Center(
                    child: SizedBox(
                      width: widget.size * 0.4,
                      height: widget.size * 0.4,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(iconColor),
                      ),
                    ),
                  )
                : Icon(widget.icon, color: enabled ? iconColor : iconColor.withAlpha(100), size: widget.size * 0.45),
          ),
        ),
      ),
    );
  }
}