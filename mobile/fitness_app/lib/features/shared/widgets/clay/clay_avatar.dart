import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../../../../app/design_tokens.dart';

enum ClayAvatarSize { xs, sm, md, lg, xl }

enum ClayAvatarStyle { circle, rounded }

class ClayAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final ClayAvatarSize size;
  final ClayAvatarStyle style;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double borderWidth;
  final bool showOnlineIndicator;
  final bool isOnline;
  final Color? onlineColor;
  final VoidCallback? onTap;

  const ClayAvatar({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = ClayAvatarSize.md,
    this.style = ClayAvatarStyle.circle,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.borderWidth = 2,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onlineColor,
    this.onTap,
  });

  double get _size {
    switch (size) {
      case ClayAvatarSize.xs:
        return 24;
      case ClayAvatarSize.sm:
        return 32;
      case ClayAvatarSize.md:
        return 44;
      case ClayAvatarSize.lg:
        return 56;
      case ClayAvatarSize.xl:
        return 80;
    }
  }

  double get _fontSize => _size * 0.35;

  double get _indicatorSize => _size * 0.25;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = style == ClayAvatarStyle.circle ? _size / 2 : _size * 0.25;

    final avatar = Container(
      width: _size,
      height: _size,
      decoration: BoxDecoration(
        shape: style == ClayAvatarStyle.circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: style == ClayAvatarStyle.rounded ? BorderRadius.circular(radius) : null,
        gradient: backgroundColor != null
            ? null
            : LinearGradient(
                colors: isDark
                    ? [ClayTokens.clayPrimaryDark, ClayTokens.clayPrimary]
                    : [ClayTokens.clayPrimaryLight, ClayTokens.clayPrimary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: backgroundColor,
        border: borderColor != null ? Border.all(color: borderColor!, width: borderWidth) : null,
        boxShadow: [
          BoxShadow(
            color: (isDark ? ClayTokens.clayDarkShadowDark : ClayTokens.clayShadowDark).withAlpha(30),
            offset: Offset(_size * 0.05, _size * 0.05),
            blurRadius: _size * 0.15,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: (isDark ? ClayTokens.clayDarkShadowLight : ClayTokens.clayShadowLight).withAlpha(150),
            offset: Offset(-_size * 0.03, -_size * 0.03),
            blurRadius: _size * 0.1,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: imageUrl != null
            ? Image.network(
                imageUrl!,
                width: _size,
                height: _size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildInitials(isDark),
              )
            : _buildInitials(isDark),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          Haptics.vibrate(HapticsType.light);
          onTap?.call();
        },
        child: _buildWithIndicator(avatar, isDark),
      );
    }

    return _buildWithIndicator(avatar, isDark);
  }

  Widget _buildWithIndicator(Widget avatar, bool isDark) {
    if (!showOnlineIndicator) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -_indicatorSize * 0.3,
          bottom: -_indicatorSize * 0.3,
          child: Container(
            width: _indicatorSize,
            height: _indicatorSize,
            decoration: BoxDecoration(
              color: isOnline ? (onlineColor ?? ClayTokens.clayAccent) : ClayTokens.clayTextTertiary,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? ClayTokens.clayDarkBase : ClayTokens.clayBase,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(30),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInitials(bool isDark) {
    final text = initials ?? '?';
    return Center(
      child: Text(
        text,
        style: GoogleFonts.nunito(
          fontSize: _fontSize,
          fontWeight: FontWeight.w800,
          color: textColor ?? (isDark ? ClayTokens.clayDarkTextInverse : ClayTokens.clayTextOnPrimary),
        ),
      ),
    );
  }
}

/// Avatar group with overlap
class ClayAvatarGroup extends StatelessWidget {
  final List<ClayAvatar> avatars;
  final int maxVisible;
  final double overlap;
  final ClayAvatarSize size;

  const ClayAvatarGroup({
    super.key,
    required this.avatars,
    this.maxVisible = 5,
    this.overlap = 0.3,
    this.size = ClayAvatarSize.md,
  });

  @override
  Widget build(BuildContext context) {
    final visibleAvatars = avatars.take(maxVisible).toList();
    final remaining = avatars.length - maxVisible;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ...visibleAvatars.asMap().entries.map((entry) {
          final index = entry.key;
          final avatar = entry.value;
          return Positioned(
            left: index * (avatar._size * (1 - overlap)),
            child: avatar,
          );
        }),
        if (remaining > 0)
          Positioned(
            left: maxVisible * (size == ClayAvatarSize.md ? 44 * (1 - 0.3) : 0),
            child: ClayAvatar(
              size: size,
              initials: '+$remaining',
              backgroundColor: ClayTokens.clayTextTertiary,
              textColor: ClayTokens.clayTextInverse,
            ),
          ),
      ],
    );
  }
}

/// Avatar with status ring
class ClayAvatarWithStatus extends StatelessWidget {
  final String? imageUrl;
  final String? initials;
  final ClayAvatarSize size;
  final Color statusColor;
  final double statusRingWidth;
  final bool showBorder;
  final VoidCallback? onTap;

  const ClayAvatarWithStatus({
    super.key,
    this.imageUrl,
    this.initials,
    this.size = ClayAvatarSize.md,
    required this.statusColor,
    this.statusRingWidth = 3,
    this.showBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarSize = size == ClayAvatarSize.xs
        ? 24.0
        : size == ClayAvatarSize.sm
            ? 32.0
            : size == ClayAvatarSize.md
                ? 44.0
                : size == ClayAvatarSize.lg
                    ? 56.0
                    : 80.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: avatarSize,
        height: avatarSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: showBorder
              ? Border.all(color: statusColor, width: statusRingWidth)
              : null,
          boxShadow: [
            BoxShadow(
              color: statusColor.withAlpha(40),
              offset: Offset(0, avatarSize * 0.05),
              blurRadius: avatarSize * 0.2,
              spreadRadius: 0,
            ),
          ],
        ),
        child: ClayAvatar(
          imageUrl: imageUrl,
          initials: initials,
          size: size,
        ),
      ),
    );
  }
}