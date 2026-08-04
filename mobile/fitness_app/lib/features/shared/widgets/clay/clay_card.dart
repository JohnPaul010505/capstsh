import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'clay_tokens.dart';

enum ClayCardVariant { elevated, outlined, filled, inset }

enum ClayCardPadding { none, small, medium, large }

class ClayCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ClayCardVariant variant;
  final ClayCardPadding padding;
  final EdgeInsetsGeometry? customPadding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final List<BoxShadow>? customShadows;
  final bool animateEntrance;
  final Duration entranceDelay;
  final Decoration? foregroundDecoration;
  final Clip clipBehavior;

  const ClayCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.variant = ClayCardVariant.elevated,
    this.padding = ClayCardPadding.medium,
    this.customPadding,
    this.borderRadius,
    this.backgroundColor,
    this.customShadows,
    this.animateEntrance = true,
    this.entranceDelay = Duration.zero,
    this.foregroundDecoration,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  State<ClayCard> createState() => _ClayCardState();
}

class _ClayCardState extends State<ClayCard> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ClayTokens.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.98).animate(
      CurvedAnimation(parent: _pressController, curve: ClayTokens.spring),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
      _pressController.forward();
      Haptics.vibrate(HapticsType.light);
    }
  }

  void _handleTapUp(_) {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
      _pressController.reverse();
    }
  }

  void _handleHover(bool hovered) {
    setState(() => _isHovered = hovered);
  }

  EdgeInsetsGeometry get _padding {
    if (widget.customPadding != null) return widget.customPadding!;
    switch (widget.padding) {
      case ClayCardPadding.none:
        return EdgeInsets.zero;
      case ClayCardPadding.small:
        return EdgeInsets.all(ClayTokens.sm);
      case ClayCardPadding.medium:
        return EdgeInsets.all(ClayTokens.md);
      case ClayCardPadding.large:
        return EdgeInsets.all(ClayTokens.lg);
    }
  }

  List<BoxShadow> get _shadows {
    if (widget.customShadows != null) return widget.customShadows!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.variant == ClayCardVariant.inset) {
      return isDark ? ClayTokens.darkLevel1 : ClayTokens.pressed;
    }

    final level = widget.variant == ClayCardVariant.filled ? 1 :
        widget.variant == ClayCardVariant.outlined ? 0 : 2;

    if (isDark) {
      return level == 0 ? ClayTokens.darkLevel0 :
          level == 1 ? ClayTokens.darkLevel1 : ClayTokens.darkLevel2;
    }
    return level == 0 ? ClayTokens.level0 :
        level == 1 ? ClayTokens.level1 : ClayTokens.level2;
  }

  Color get _bgColor {
    if (widget.backgroundColor != null) return widget.backgroundColor!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.variant == ClayCardVariant.filled) {
      return isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated;
    }
    if (widget.variant == ClayCardVariant.outlined) {
      return isDark ? ClayTokens.clayDarkSurface : ClayTokens.claySurface;
    }
    return isDark ? ClayTokens.clayDarkCard : ClayTokens.clayCard;
  }

  Color get _borderColor {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (widget.variant == ClayCardVariant.outlined) {
      return isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final card = AnimatedBuilder(
      animation: _pressController,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnimation.value,
        child: MouseRegion(
          onEnter: (_) => _handleHover(true),
          onExit: (_) => _handleHover(false),
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: AnimatedContainer(
              duration: ClayTokens.normal,
              curve: ClayTokens.easeOut,
              padding: _padding,
              decoration: BoxDecoration(
                color: _bgColor,
                borderRadius: widget.borderRadius ?? BorderRadius.circular(ClayTokens.radiusCard),
                border: Border.all(color: _borderColor, width: widget.variant == ClayCardVariant.outlined ? 1.5 : 1),
                boxShadow: _isPressed || _isHovered ? [] : _shadows,
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );

  if (widget.animateEntrance) {
    return card
        .animate(delay: widget.entranceDelay)
        .fadeIn(duration: ClayTokens.normal, curve: ClayTokens.easeOut)
        .slideY(begin: 0.1, end: 0, duration: ClayTokens.normal, curve: ClayTokens.easeOut);
  }

    return card;
  }
}

/// Specialized stat card for dashboard metrics
class ClayStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final ClayCardVariant variant;

  const ClayStatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.iconBgColor,
    this.onTap,
    this.trailing,
    this.variant = ClayCardVariant.elevated,
  });

  @override
  Widget build(BuildContext context) {

    return ClayCard(
      variant: variant,
      padding: ClayCardPadding.medium,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor ?? iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          SizedBox(width: ClayTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: ClayTokens.bodySmall),
                SizedBox(height: 2),
                Text(value, style: ClayTokens.headlineMedium),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle!, style: ClayTokens.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Feature card for settings/profile menus
class ClayFeatureCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color iconColor;
  final Color? iconBgColor;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showChevron;
  final BorderRadius? borderRadius;

  const ClayFeatureCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.iconColor,
    this.iconBgColor,
    this.onTap,
    this.trailing,
    this.showChevron = true,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClayCard(
      variant: ClayCardVariant.elevated,
      padding: ClayCardPadding.medium,
      borderRadius: borderRadius,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBgColor ?? iconColor.withAlpha(30),
              borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          SizedBox(width: ClayTokens.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ClayTokens.titleMedium),
                if (subtitle != null) ...[
                  SizedBox(height: 2),
                  Text(subtitle!, style: ClayTokens.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (showChevron && onTap != null)
            Icon(
              Icons.chevron_right,
              color: isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary,
              size: 20,
            ),
        ],
      ),
    );
  }
}

/// Horizontal progress card (workout progress, etc.)
class ClayProgressCard extends StatelessWidget {
  final String label;
  final String value;
  final double progress; // 0.0 to 1.0
  final Color progressColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const ClayProgressCard({
    super.key,
    required this.label,
    required this.value,
    required this.progress,
    required this.progressColor,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClayCard(
      variant: ClayCardVariant.elevated,
      padding: ClayCardPadding.medium,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              SizedBox(width: 6),
              Text(label, style: ClayTokens.titleSmall),
              Spacer(),
              Text(value, style: ClayTokens.labelLarge.copyWith(color: progressColor)),
            ],
          ),
          SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 6,
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: ClayTokens.clayBorder,
                valueColor: AlwaysStoppedAnimation(progressColor),
                minHeight: 6,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glass/clay hybrid card for modial style card
class ClayModalCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? maxWidth;
  final BorderRadius? borderRadius;

  const ClayModalCard({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth ?? 500),
      child: Container(
        padding: padding ?? EdgeInsets.all(ClayTokens.xl),
        decoration: BoxDecoration(
          color: isDark ? ClayTokens.clayDarkCard : ClayTokens.clayCard,
          borderRadius: borderRadius ?? BorderRadius.circular(ClayTokens.radiusOuter),
          boxShadow: isDark ? ClayTokens.darkLevel3 : ClayTokens.level3,
        ),
        child: child,
      ),
    ).animate().fadeIn(duration: ClayTokens.normal).scale(
      begin: const Offset(0.95, 0.95),
      duration: ClayTokens.normal,
      curve: ClayTokens.spring,
    );
  }
}

/// Empty state card
class ClayEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ClayEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClayCard(
      variant: ClayCardVariant.filled,
      padding: ClayCardPadding.large,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary),
          ),
          SizedBox(height: ClayTokens.lg),
          Text(title, style: ClayTokens.headlineSmall, textAlign: TextAlign.center),
          SizedBox(height: ClayTokens.sm),
          Text(message, style: ClayTokens.bodyMedium, textAlign: TextAlign.center),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: ClayTokens.xl),
            ClayButton(
              label: actionLabel!,
              onPressed: onAction,
              style: ClayButtonStyle.primary,
              size: ClayButtonSize.medium,
            ),
          ],
        ],
      ),
    );
  }
}