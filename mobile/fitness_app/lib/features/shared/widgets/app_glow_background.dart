import 'package:flutter/material.dart';

class AppGlowBackground extends StatelessWidget {
  final Widget child;
  const AppGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
         const Positioned(top: -80, right: -60, child: _GlowBlob(size: 220, colors: [Color(0x337C3AED), Color(0x007C3AED)])),
         const Positioned(top: 40, left: -70, child: _GlowBlob(size: 200, colors: [Color(0x33A78BFA), Color(0x00A78BFA)])),
         const Positioned(top: 260, right: -90, child: _GlowBlob(size: 260, colors: [Color(0x33A78BFA), Color(0x00A78BFA)])),
         const Positioned(bottom: -60, left: -70, child: _GlowBlob(size: 240, colors: [Color(0x336D28D9), Color(0x006D28D9)])),
        child,
      ],
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double size;
  final List<Color> colors;

  const _GlowBlob({required this.size, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: colors),
      ),
    );
  }
}
