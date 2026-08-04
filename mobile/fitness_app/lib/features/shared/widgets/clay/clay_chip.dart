import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../../../../app/design_tokens.dart';

enum ClayChipStyle { filled, outlined, ghost }
enum ClayChipSize { small, medium, large }

class ClayChip extends StatefulWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onTap;
  final ClayChipStyle style;
  final ClayChipSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final Color? selectedColor;
  final Color? unselectedColor;
  final bool enabled;
  final bool showCheckmark;
  final EdgeInsetsGeometry? padding;

  const ClayChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onTap,
    this.style = ClayChipStyle.filled,
    this.size = ClayChipSize.medium,
    this.leadingIcon,
    this.trailingIcon,
    this.selectedColor,
    this.unselectedColor,
    this.enabled = true,
    this.showCheckmark = false,
    this.padding,
  });

  @override
  State<ClayChip> createState() => _ClayChipState();
}

class _ClayChipState extends State<ClayChip> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ClayTokens.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: ClayTokens.spring),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.enabled) {
      _pressController.forward();
      Haptics.vibrate(HapticsType.light);
    }
  }

  void _handleTapUp(_) {
    if (widget.enabled) {
      _pressController.reverse();
      _handleTap();
    }
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    if (widget.onSelected != null) {
      widget.onSelected?.call(!widget.selected);
    }
    widget.onTap?.call();
  }

  EdgeInsetsGeometry get _padding {
    if (widget.padding != null) return widget.padding!;
    final horizontal = widget.size == ClayChipSize.small
        ? ClayTokens.md
        : widget.size == ClayChipSize.medium
            ? ClayTokens.lg
            : ClayTokens.xl;
final vertical = widget.size == ClayChipSize.small
        ? ClayTokens.xs
        : widget.size == ClayChipSize.medium
            ? ClayTokens.sm
            : ClayTokens.md;
    return widget.padding ?? EdgeInsets.symmetric(horizontal: horizontal, vertical: vertical);
  }

  double get _fontSize {
    return widget.size == ClayChipSize.small ? 12 : widget.size == ClayChipSize.medium ? 14 : 16;
  }

  double get _iconSize {
    return widget.size == ClayChipSize.small ? 14 : widget.size == ClayChipSize.medium ? 16 : 18;
  }

  BorderRadius get _borderRadius {
    return BorderRadius.circular(ClayTokens.radiusPill);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.selected;
    final enabled = widget.enabled;

    Color bgColor;
    Color textColor;
    Color borderColor;
    List<BoxShadow> shadows = [];

    if (widget.style == ClayChipStyle.filled) {
      if (isSelected) {
        bgColor = widget.selectedColor ?? ClayTokens.clayPrimary;
        textColor = ClayTokens.clayTextOnPrimary;
        shadows = ClayTokens.level1;
      } else {
        bgColor = isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated;
        textColor = isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary;
        shadows = ClayTokens.level0;
      }
      borderColor = Colors.transparent;
    } else if (widget.style == ClayChipStyle.outlined) {
      bgColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary).withAlpha(30)
          : (isDark ? ClayTokens.clayDarkSurface : ClayTokens.claySurface);
      textColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary)
          : (isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary);
      borderColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary)
          : (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder);
      shadows = ClayTokens.level0;
    } else {
      bgColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary).withAlpha(30)
          : (isDark ? ClayTokens.clayDarkSurface : ClayTokens.claySurface);
      textColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary)
          : (isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary);
      borderColor = isSelected
          ? (widget.selectedColor ?? ClayTokens.clayPrimary)
          : (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder);
      shadows = ClayTokens.level0;
    }

    final opacity = enabled ? 1.0 : 0.5;

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnimation.value,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: _handleTap,
          child: AnimatedContainer(
            duration: ClayTokens.fast,
            curve: ClayTokens.easeOut,
            padding: widget.padding ?? _padding,
            decoration: BoxDecoration(
              color: bgColor.withAlpha((opacity * 255).round()),
              borderRadius: _borderRadius,
              border: Border.all(
                color: borderColor.withAlpha((opacity * 255).round()),
                width: widget.style == ClayChipStyle.ghost ? 1.5 : (widget.style == ClayChipStyle.outlined ? 1.5 : 0),
              ),
              boxShadow: enabled ? shadows : [],
            ),
            child: Opacity(
              opacity: opacity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.leadingIcon != null) ...[
                    Icon(widget.leadingIcon, size: _iconSize, color: textColor),
                    SizedBox(width: ClayTokens.xs),
                  ],
                  Text(
                    widget.label,
                    style: ClayTokens.labelMedium.copyWith(
                      fontSize: _fontSize,
                      color: textColor,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (widget.trailingIcon != null) ...[
                    SizedBox(width: ClayTokens.xs),
                    Icon(widget.trailingIcon, size: _iconSize, color: textColor),
                  ],
                  if (isSelected && widget.showCheckmark) ...[
                    SizedBox(width: ClayTokens.xs),
                    Icon(Icons.check, size: _iconSize, color: textColor),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filter chips group with single/multi selection
class ClayFilterChips extends StatefulWidget {
  final List<String> options;
  final List<String>? initialSelection;
  final bool multiSelect;
  final ValueChanged<List<String>>? onChanged;
  final ClayChipStyle style;
  final ClayChipSize size;
  final ScrollController? scrollController;

  const ClayFilterChips({
    super.key,
    required this.options,
    this.initialSelection,
    this.multiSelect = false,
    this.onChanged,
    this.style = ClayChipStyle.filled,
    this.size = ClayChipSize.medium,
    this.scrollController,
  });

  @override
  State<ClayFilterChips> createState() => _ClayFilterChipsState();
}

class _ClayFilterChipsState extends State<ClayFilterChips> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelection?.toSet() ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: widget.scrollController,
      padding: EdgeInsets.symmetric(horizontal: ClayTokens.md),
      child: Row(
        children: widget.options.map((option) {
          final isSelected = _selected.contains(option);
          return Padding(
            padding: EdgeInsets.only(right: ClayTokens.sm),
            child: ClayChip(
              label: option,
              selected: isSelected,
              style: widget.style,
              size: widget.size,
              onSelected: (selected) {
                setState(() {
                  if (widget.multiSelect) {
                    if (selected) _selected.add(option);
                    else _selected.remove(option);
                  } else {
                    _selected = {option};
                  }
                  widget.onChanged?.call(_selected.toList());
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Input chip with delete action
class ClayInputChip extends StatefulWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onDeleted;
  final ClayChipStyle style;
  final ClayChipSize size;
  final IconData? avatar;
  final Color? avatarColor;
  final Color? deleteIconColor;
  final bool enabled;

  const ClayInputChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.onDeleted,
    this.style = ClayChipStyle.filled,
    this.size = ClayChipSize.medium,
    this.avatar,
    this.avatarColor,
    this.deleteIconColor,
    this.enabled = true,
  });

  @override
  State<ClayInputChip> createState() => _ClayInputChipState();
}

class _ClayInputChipState extends State<ClayInputChip> with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: ClayTokens.fast,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _pressController, curve: ClayTokens.spring),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    if (widget.enabled) {
      _pressController.forward();
      Haptics.vibrate(HapticsType.light);
    }
  }

  void _handleTapUp(_) {
    if (widget.enabled) {
      _pressController.reverse();
      _handleTap();
    }
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  void _handleTap() {
    if (!widget.enabled) return;
    widget.onSelected?.call(!widget.selected);
  }

  void _handleDelete() {
    Haptics.vibrate(HapticsType.light);
    widget.onDeleted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = widget.selected;
    final enabled = widget.enabled;

    final bgColor = isSelected
        ? (widget.style == ClayChipStyle.filled
            ? ClayTokens.clayPrimary
            : ClayTokens.clayPrimary.withAlpha(30))
        : (isDark ? ClayTokens.clayDarkSurfaceElevated : ClayTokens.claySurfaceElevated);

    final textColor = isSelected
        ? (widget.style == ClayChipStyle.filled ? ClayTokens.clayTextOnPrimary : ClayTokens.clayPrimary)
        : (isDark ? ClayTokens.clayDarkTextPrimary : ClayTokens.clayTextPrimary);

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, _) => Transform.scale(
        scale: _scaleAnimation.value,
        child: GestureDetector(
          onTapDown: _handleTapDown,
          onTapUp: _handleTapUp,
          onTapCancel: _handleTapCancel,
          onTap: () {
            if (!widget.enabled) return;
            widget.onSelected?.call(!widget.selected);
          },
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: ClayTokens.md,
                vertical: ClayTokens.xs,
              ),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(ClayTokens.radiusPill),
                border: Border.all(
                  color: isSelected ? ClayTokens.clayPrimary : (isDark ? ClayTokens.clayDarkBorder : ClayTokens.clayBorder),
                  width: widget.style == ClayChipStyle.outlined ? 1.5 : 0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.avatar != null) ...[
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: widget.avatarColor ?? ClayTokens.clayPrimary,
                      child: Icon(widget.avatar, size: 12, color: ClayTokens.clayTextOnPrimary),
                    ),
                    SizedBox(width: ClayTokens.xs),
                  ],
                  Text(
                    widget.label,
                    style: ClayTokens.labelMedium.copyWith(
                      color: textColor,
                      fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (widget.onDeleted != null) ...[
                    SizedBox(width: ClayTokens.xs),
                    GestureDetector(
                      onTap: _handleDelete,
                      child: Icon(
                        Icons.close,
                        size: 16,
                        color: widget.deleteIconColor ?? (isDark ? ClayTokens.clayDarkTextTertiary : ClayTokens.clayTextTertiary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}