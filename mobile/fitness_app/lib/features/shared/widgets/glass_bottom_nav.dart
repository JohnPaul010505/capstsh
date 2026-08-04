import 'package:flutter/material.dart';
import '../../../app/design_tokens.dart';
import 'nav_icons.dart';

class GlassNavItem {
  final NavIconType type;
  final String label;

  const GlassNavItem({
    required this.type,
    required this.label,
  });
}

class GlassBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;

  const GlassBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<GlassBottomNav> createState() => _GlassBottomNavState();
}

class _GlassBottomNavState extends State<GlassBottomNav>
    with TickerProviderStateMixin {
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entrance;

  @override
  void initState() {
    super.initState();
    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entrance = CurvedAnimation(
      parent: _entranceCtrl,
      curve: Curves.easeOutBack,
    );
    _entranceCtrl.forward();
  }

  @override
  void dispose() {
    _entranceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 8),
      child: ScaleTransition(
        scale: _entrance,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: ClayTokens.clayDarkSurface,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: ClayTokens.clayDarkBorder.withAlpha(100),
              width: 0.5,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalW = constraints.maxWidth;
              final count = widget.items.length;
              final activeW = totalW * 0.44;
              final inactiveW = (totalW - activeW) / (count - 1).clamp(1, count);

              return Stack(
                children: List.generate(count, (i) {
                  final isActive = i == widget.currentIndex;

                  final left = isActive
                      ? i * inactiveW
                      : i < widget.currentIndex
                          ? i * inactiveW
                          : activeW + (i - 1) * inactiveW;
                  final width = isActive ? activeW : inactiveW;

                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    left: left,
                    width: width,
                    top: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: () => widget.onTap(i),
                      behavior: HitTestBehavior.opaque,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                            alignment: isActive
                                ? Alignment.centerLeft
                                : Alignment.center,
                            child: Padding(
                              padding: isActive
                                  ? const EdgeInsets.only(left: 10)
                                  : EdgeInsets.zero,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        TweenAnimationBuilder<double>(
                                          tween: isActive
                                              ? Tween(begin: 0.0, end: 1.0)
                                              : Tween(begin: 1.0, end: 0.0),
                                          duration:
                                              const Duration(milliseconds: 300),
                                          curve: Curves.easeOutBack,
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: value,
                                              child: child,
                                            );
                                          },
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: ClayTokens.clayPrimary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ),
                                        NavIcon(
                                          type: widget.items[i].type,
                                          isActive: isActive,
                                          size: 20,
                                          activeColor:
                                              ClayTokens.clayDarkTextPrimary,
                                          inactiveColor:
                                              ClayTokens.clayDarkTextTertiary,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isActive)
                                    Flexible(
                                      child: TweenAnimationBuilder<double>(
                                        tween: Tween(begin: 0.0, end: 1.0),
                                        duration:
                                            const Duration(milliseconds: 300),
                                        curve: Curves.easeOut,
                                        builder: (context, value, child) {
                                          return Opacity(
                                            opacity: value,
                                            child: Transform.translate(
                                              offset:
                                                  Offset(0, (1 - value) * 20),
                                              child: child,
                                            ),
                                          );
                                        },
                                        child: Padding(
                                          padding:
                                              const EdgeInsets.only(left: 6),
                                          child: Text(
                                            widget.items[i].label,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  ClayTokens.clayDarkTextPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 4,
                            left: 12,
                            right: 12,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              height: isActive ? 2.5 : 0,
                              decoration: BoxDecoration(
                                color: ClayTokens.clayPrimary,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}
