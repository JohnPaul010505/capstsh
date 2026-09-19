import 'package:flutter/material.dart';

class AppGlowBackground extends StatelessWidget {
  final Widget child;
  const AppGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Top band
        const Positioned(top: -80, right: -60, child: _GlowBlob(size: 230, colors: [Color(0x4D7C3AED), Color(0x007C3AED)])),
        const Positioned(top: 30, left: -80, child: _GlowBlob(size: 220, colors: [Color(0x4DA78BFA), Color(0x00A78BFA)])),
        const Positioned(top: 120, right: 40, child: _GlowBlob(size: 150, colors: [Color(0x3DD946EF), Color(0x00D946EF)])),
        // Middle band
        const Positioned(top: 330, left: -90, child: _GlowBlob(size: 250, colors: [Color(0x3D5E3AEE), Color(0x005E3AEE)])),
        const Positioned(top: 430, right: -80, child: _GlowBlob(size: 240, colors: [Color(0x40EC4899), Color(0x00EC4899)])),
        // Lower band
        const Positioned(bottom: 60, left: 30, child: _GlowBlob(size: 170, colors: [Color(0x3322D3EE), Color(0x0022D3EE)])),
        const Positioned(bottom: -70, right: -70, child: _GlowBlob(size: 260, colors: [Color(0x4D6D28D9), Color(0x006D28D9)])),
        const Positioned(bottom: -30, left: -60, child: _GlowBlob(size: 200, colors: [Color(0x40C56BF0), Color(0x00C56BF0)])),
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
