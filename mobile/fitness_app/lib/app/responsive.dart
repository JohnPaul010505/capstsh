import 'package:flutter/material.dart';
import 'design_tokens.dart';

enum DeviceType { phone, tablet, desktop }

enum LayoutMode { compact, regular, expanded }

class ResponsiveContext {
  final BuildContext context;
  final double width;
  final double height;
  final DeviceType deviceType;
  final LayoutMode layoutMode;
  final double textScaleFactor;
  final bool isLandscape;
  final EdgeInsets safeArea;
  final EdgeInsets viewPadding;

  const ResponsiveContext({
    required this.context,
    required this.width,
    required this.height,
    required this.deviceType,
    required this.layoutMode,
    required this.textScaleFactor,
    required this.isLandscape,
    required this.safeArea,
    required this.viewPadding,
  });

  // Breakpoint checks
  bool get isPhone => deviceType == DeviceType.phone;
  bool get isTablet => deviceType == DeviceType.tablet;
  bool get isDesktop => deviceType == DeviceType.desktop;

  bool get isCompact => layoutMode == LayoutMode.compact;
  bool get isRegular => layoutMode == LayoutMode.regular;
  bool get isExpanded => layoutMode == LayoutMode.expanded;

  // Responsive values
  double get pageHorizontalPadding {
    if (isPhone) return ClayTokens.pageHorizontal;
    if (isTablet) return ClayTokens.pageHorizontalLarge;
    return ClayTokens.pageHorizontalLarge * 1.5;
  }

  double get cardRadius => isTablet ? ClayTokens.radiusCard + 4 : ClayTokens.radiusCard;
  double get buttonRadius => ClayTokens.radiusButton;
  double get iconSizeSmall => isTablet ? 22 : 18;
  double get iconSizeMedium => isTablet ? 26 : 20;
  double get iconSizeLarge => isTablet ? 32 : 24;

  double get appBarHeight => isPhone ? 56 : 64;
  double get bottomNavHeight => isPhone ? 64 : 72;

  // Column counts for grids
  int get gridColumns {
    if (width < ClayTokens.phoneMedium) return 1;
    if (width < ClayTokens.tabletPortrait) return 2;
    if (width < ClayTokens.tabletLandscape) return 3;
    return 4;
  }

  // Spacing scale
  double get spacingXS => ClayTokens.xs;
  double get spacingSM => ClayTokens.sm;
  double get spacingMD => ClayTokens.md;
  double get spacingLG => ClayTokens.lg;
  double get spacingXL => ClayTokens.xl;
  double get spacingXXL => ClayTokens.xxl;

  // Typography scale (respects textScaleFactor, capped)
  double scaleFont(double baseSize) {
    final scaled = baseSize * textScaleFactor.clamp(0.85, 1.3);
    return scaled.clamp(baseSize * 0.85, baseSize * 1.3);
  }

  TextStyle scaleStyle(TextStyle style) {
    return style.copyWith(fontSize: scaleFont(style.fontSize ?? 14));
  }
}

/// Extension to access ResponsiveContext from BuildContext
extension ResponsiveContextExtension on BuildContext {
  ResponsiveContext get responsive {
    final mediaQuery = MediaQuery.of(this);
    final width = mediaQuery.size.width;
    final height = mediaQuery.size.height;
    final isLandscape = width > height;

    DeviceType deviceType;
    if (width < ClayTokens.tabletPortrait) {
      deviceType = DeviceType.phone;
    } else if (width < ClayTokens.desktop) {
      deviceType = DeviceType.tablet;
    } else {
      deviceType = DeviceType.desktop;
    }

    LayoutMode layoutMode;
    if (deviceType == DeviceType.phone) {
      layoutMode = LayoutMode.compact;
    } else if (deviceType == DeviceType.tablet) {
      layoutMode = isLandscape ? LayoutMode.expanded : LayoutMode.regular;
    } else {
      layoutMode = LayoutMode.expanded;
    }

    return ResponsiveContext(
      context: this,
      width: width,
      height: height,
      deviceType: deviceType,
      layoutMode: layoutMode,
      textScaleFactor: mediaQuery.textScaler.scale(1.0),
      isLandscape: isLandscape,
      safeArea: mediaQuery.padding,
      viewPadding: mediaQuery.viewPadding,
    );
  }
}

/// Builder that provides ResponsiveContext
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext, ResponsiveContext) builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return builder(context, context.responsive);
      },
    );
  }
}

/// Master-detail adaptive layout
class AdaptiveMasterDetail extends StatelessWidget {
  final Widget master;
  final Widget detail;
  final double masterWidth;
  final double minDetailWidth;
  final bool showDivider;

  const AdaptiveMasterDetail({
    super.key,
    required this.master,
    required this.detail,
    this.masterWidth = 320,
    this.minDetailWidth = 400,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, rc) {
        if (rc.isPhone) {
          return detail;
        }

        if (rc.isTablet && !rc.isLandscape) {
          return master;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: masterWidth,
                minWidth: masterWidth,
              ),
              child: ColoredBox(
                color: ClayTokens.claySurface,
                child: master,
              ),
            ),
            if (showDivider)
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: ClayTokens.clayDivider,
              ),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: minDetailWidth),
                child: detail,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Responsive value helper
class ResponsiveValue<T> {
  final T phone;
  final T? tablet;
  final T? desktop;

  const ResponsiveValue({
    required this.phone,
    this.tablet,
    this.desktop,
  });

  T resolve(ResponsiveContext rc) {
    if (rc.isDesktop && desktop != null) return desktop!;
    if (rc.isTablet && tablet != null) return tablet!;
    return phone;
  }
}

extension ResponsiveValueExtension<T> on ResponsiveValue<T> {
  T get(BuildContext context) => resolve(context.responsive);
}

/// Responsive gap widget
class ResponsiveGap extends StatelessWidget {
  final double? phone;
  final double? tablet;
  final double? desktop;

  const ResponsiveGap({super.key, this.phone, this.tablet, this.desktop});

  @override
  Widget build(BuildContext context) {
    final rc = context.responsive;
    double size;
    if (rc.isDesktop && desktop != null) size = desktop!;
    else if (rc.isTablet && tablet != null) size = tablet!;
    else size = phone ?? ClayTokens.md;

    return SizedBox(height: size, width: size);
  }
}

/// Responsive padding widget
class ResponsivePadding extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? phone;
  final EdgeInsetsGeometry? tablet;
  final EdgeInsetsGeometry? desktop;

  const ResponsivePadding({
    super.key,
    required this.child,
    this.phone,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final rc = context.responsive;
    EdgeInsetsGeometry padding;
    if (rc.isDesktop && desktop != null) padding = desktop!;
    else if (rc.isTablet && tablet != null) padding = tablet!;
    else padding = phone ?? EdgeInsets.symmetric(horizontal: rc.pageHorizontalPadding, vertical: ClayTokens.md);

    return Padding(padding: padding, child: child);
  }
}

/// Animated responsive container
class AdaptiveContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Decoration? decoration;
  final Duration duration;
  final Curve curve;

  const AdaptiveContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.decoration,
    this.duration = const Duration(milliseconds: 200),
    this.curve = Curves.easeOutCubic,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, rc) {
        return AnimatedContainer(
          duration: duration,
          curve: curve,
          width: width,
          height: height,
          padding: padding ?? EdgeInsets.all(rc.spacingMD),
          decoration: decoration,
          child: child,
        );
      },
    );
  }
}

/// Responsive grid builder
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? phoneColumns;
  final int? tabletColumns;
  final int? desktopColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.phoneColumns,
    this.tabletColumns,
    this.desktopColumns,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveBuilder(
      builder: (context, rc) {
        int columns;
        if (rc.isDesktop) columns = desktopColumns ?? 4;
        else if (rc.isTablet) columns = tabletColumns ?? 3;
        else columns = phoneColumns ?? 2;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) => ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: (rc.width - spacing * (columns - 1)) / columns,
            ),
            child: child,
          )).toList(),
        );
      },
    );
  }
}