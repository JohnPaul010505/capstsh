import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'design_tokens.dart';
import 'theme_mode_provider.dart';
import '../features/shared/widgets/glass_card.dart';

/// Appearance control styled after the admin's compact animated day/night switch.
class ThemeModeToggle extends ConsumerWidget {
  const ThemeModeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLight = ref.watch(themeModeProvider) == ThemeMode.light;
    final colors = Theme.of(context).colorScheme;
    // Light mode: render the shared liquid-glass body ([GlassSurface]) so the
    // Appearance card matches the Features cards (BMI/Feedback/…).
    // Dark mode keeps the original dark surface untouched.
    final useGlass = ClayColors.isLightMode;

    final row = Row(
      children: [
        Icon(Icons.brightness_6_outlined, color: colors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                isLight ? 'Light mode' : 'Dark mode',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _AdminStyleSwitch(isLight: isLight),
      ],
    );

    return Semantics(
      label: 'Light mode',
      value: isLight ? 'On' : 'Off',
      toggled: isLight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(useGlass ? 12 : 16),
          onTap: () => ref.read(themeModeProvider.notifier).toggle(),
          child: useGlass
              // Same body (gradient + rim + glow) as the feature cards.
              ? GlassSurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  // 44 + the 24px vertical padding keeps the original 68px
                  // minimum card height.
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: row,
                  ),
                )
              : Container(
                  constraints: const BoxConstraints(minHeight: 68),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: ClayTokens.clayDarkSurface.withAlpha(220),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: row,
                ),
        ),
      ),
    );
  }
}

class _AdminStyleSwitch extends StatelessWidget {
  const _AdminStyleSwitch({required this.isLight});

  final bool isLight;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: 62,
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: isLight
              ? const [Color(0xFF72D6F2), Color(0xFF52B9E7)]
              : const [Color(0xFF191A37), Color(0xFF29244A)],
        ),
        border: Border.all(
          color: isLight ? const Color(0xFF67C6EA) : const Color(0xFF514878),
        ),
      ),
      child: Stack(
        children: [
          if (isLight) ...[
            const Positioned(left: 7, top: 8, child: _Cloud()),
            const Positioned(right: 8, top: 5, child: _Cloud(small: true)),
          ] else ...[
            const Positioned(left: 8, top: 7, child: _Star(size: 3)),
            const Positioned(left: 17, top: 21, child: _Star(size: 2)),
            const Positioned(right: 8, top: 7, child: _Star(size: 2)),
          ],
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: isLight ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLight
                    ? const Color(0xFFFFC928)
                    : const Color(0xFFEDEBFF),
                boxShadow: [
                  BoxShadow(
                    color: (isLight ? const Color(0xFFFFC928) : Colors.white)
                        .withAlpha(90),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                isLight ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
                size: 17,
                color: isLight
                    ? const Color(0xFF9B6500)
                    : const Color(0xFF514878),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      color: Color(0xFFE4E2FF),
    ),
  );
}

class _Cloud extends StatelessWidget {
  const _Cloud({this.small = false});
  final bool small;

  @override
  Widget build(BuildContext context) => Icon(
    Icons.cloud_rounded,
    size: small ? 11 : 15,
    color: Colors.white.withAlpha(220),
  );
}
