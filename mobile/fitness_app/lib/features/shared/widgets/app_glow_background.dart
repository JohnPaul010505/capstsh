import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme_mode_provider.dart';

class AppGlowBackground extends ConsumerWidget {
  final Widget child;
  const AppGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeModeProvider) == ThemeMode.light;
    // In light mode the glow blobs are dimmed so white glass panels and dark
    // text stay legible over the pastel wash; dark mode keeps the full neon.
    final dim = isLight ? 0.5 : 1.0;
    Color blob(int argb) => Color(argb).withAlpha((0xFF * (((argb >> 24) & 0xFF) / 255.0) * dim).round().clamp(0, 255));
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            // Light mode base is off-white (the clayBase token value,
            // 0xFFF4F1FA) instead of pure white: pure white was too bright and
            // washed out every translucent glass card stacked on top of it.
            color: isLight
                ? const Color(0xFFF4F1FA)
                : const Color(0xFF0D0D1A),
          ),
        ),
        // Top band
        Positioned(
          top: -80,
          right: -60,
          child: _GlowBlob(
            size: 230,
            colors: [blob(0x4D7C3AED), blob(0x007C3AED)],
          ),
        ),
        Positioned(
          top: 30,
          left: -80,
          child: _GlowBlob(
            size: 220,
            colors: [blob(0x4DA78BFA), blob(0x00A78BFA)],
          ),
        ),
        Positioned(
          top: 120,
          right: 40,
          child: _GlowBlob(
            size: 150,
            colors: [blob(0x3DD946EF), blob(0x00D946EF)],
          ),
        ),
        // Middle band
        Positioned(
          top: 330,
          left: -90,
          child: _GlowBlob(
            size: 250,
            colors: [blob(0x3D5E3AEE), blob(0x005E3AEE)],
          ),
        ),
        Positioned(
          top: 430,
          right: -80,
          child: _GlowBlob(
            size: 240,
            colors: [blob(0x40EC4899), blob(0x00EC4899)],
          ),
        ),
        // Lower band
        Positioned(
          bottom: 60,
          left: 30,
          child: _GlowBlob(
            size: 170,
            colors: [blob(0x3322D3EE), blob(0x0022D3EE)],
          ),
        ),
        Positioned(
          bottom: -70,
          right: -70,
          child: _GlowBlob(
            size: 260,
            colors: [blob(0x4D6D28D9), blob(0x006D28D9)],
          ),
        ),
        Positioned(
          bottom: -30,
          left: -60,
          child: _GlowBlob(
            size: 200,
            colors: [blob(0x40C56BF0), blob(0x00C56BF0)],
          ),
        ),
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
