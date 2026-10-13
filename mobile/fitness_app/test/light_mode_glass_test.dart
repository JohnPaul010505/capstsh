import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fitness_app/features/shared/widgets/clay/clay_tokens.dart';
import 'package:fitness_app/features/shared/widgets/glass_card.dart';
import 'package:fitness_app/features/shared/widgets/pressable.dart';

/// The member app's light-mode pass flips a set of glass surfaces and ink to a
/// light body, and MUST leave dark mode byte-for-byte identical.
///
/// Every colour that was swapped in is produced by one of the `glassXxx`
/// helpers, whose default argument is the exact literal it replaced. These
/// tests pin that contract:
///   * dark mode returns the original value untouched;
///   * light mode returns the light-body value;
///   * the card shells pick the glass branch in light mode only.
void main() {
  setUp(() => ClayColors.setBrightness(Brightness.dark));
  tearDown(() => ClayColors.setBrightness(Brightness.dark));

  group('glass helpers keep the exact dark-mode values', () {
    test('ink helpers', () {
      ClayColors.setBrightness(Brightness.dark);
      expect(glassInk(), const Color(0xFFFFFFFF));
      expect(glassInk(const Color(0xFFF2F5F7)), const Color(0xFFF2F5F7));
      expect(glassInk(const Color(0xFFECECFC)), const Color(0xFFECECFC));
      expect(glassInkDim(), const Color(0xFFB4B4D0));
      expect(glassInkDim(const Color(0xFF8E8E93)), const Color(0xFF8E8E93));
      expect(glassInkFaint(), const Color(0xFF7070A0));
    });

    test('surface helpers', () {
      ClayColors.setBrightness(Brightness.dark);
      expect(glassFill(), const Color(0x12FFFFFF));
      expect(glassFillStrong(), const Color(0x1FFFFFFF));
      expect(glassRim(), const Color(0x2EFFFFFF));
      expect(glassRimSoft(), const Color(0x26FFFFFF));
      expect(glassPanel(), const Color(0xFF1C1C35));
      expect(glassBody(), const Color(0xFF1C1C2E));
      expect(glassBody(const Color(0xFF1C1C2E)), const Color(0xFF1C1C2E));
      expect(glassLine(), const Color(0xFF2A2A45));
      expect(glassRim(const Color(0xFF3A3A4A)), const Color(0xFF3A3A4A));
      expect(glassRimSoft(const Color(0xFF2C2C2E)), const Color(0xFF2C2C2E));
      expect(glassLine(const Color(0xFF38383A)), const Color(0xFF38383A));
    });

    test('light mode flips them to ink on the light glass body', () {
      ClayColors.setBrightness(Brightness.light);
      expect(glassInk(), ClayTokens.clayTextPrimary);
      expect(glassInkDim(), ClayTokens.clayTextSecondary);
      expect(glassInkFaint(), ClayTokens.clayTextTertiary);
      expect(glassLine(), ClayTokens.clayDivider);
      expect(glassRim(), ClayTokens.clayPrimary.withAlpha(70));
      expect(glassInk(), isNot(const Color(0xFFFFFFFF)));
      // Nothing light-body may resolve to its dark value.
      expect(glassPanel(), isNot(const Color(0xFF1C1C35)));
      expect(glassBody(), isNot(const Color(0xFF1C1C2E)));
      expect(glassFill(), isNot(const Color(0x12FFFFFF)));
    });
  });

  group('card shells pick the glass body in light mode only', () {
    testWidgets('MemberGlassCard: glass in light, clay card in dark', (
      tester,
    ) async {
      ClayColors.setBrightness(Brightness.light);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MemberGlassCard(child: Text('body'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);
      expect(find.byType(ClayCard), findsNothing);

      ClayColors.setBrightness(Brightness.dark);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: MemberGlassCard(child: Text('body'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsNothing);
      expect(find.byType(ClayCard), findsOneWidget);
      // The dark branch is still the translucent lilac clay card.
      final card = tester.widget<ClayCard>(find.byType(ClayCard));
      expect(
        card.backgroundColor,
        ClayTokens.clayPrimaryLight.withAlpha(25),
      );
      expect(card.variant, ClayCardVariant.outlined);
    });

    testWidgets('MemberGlassCard honours darkBackground in dark mode', (
      tester,
    ) async {
      ClayColors.setBrightness(Brightness.dark);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MemberGlassCard(
              darkBackground: ClayTokens.clayPrimaryLight.withAlpha(45),
              child: const Text('current'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final card = tester.widget<ClayCard>(find.byType(ClayCard));
      expect(card.backgroundColor, ClayTokens.clayPrimaryLight.withAlpha(45));
    });

    testWidgets('PressableCard(glass: true): glass in light, dark pill in '
        'dark', (tester) async {
      ClayColors.setBrightness(Brightness.light);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PressableCard(glass: true, child: Text('row')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsOneWidget);

      ClayColors.setBrightness(Brightness.dark);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PressableCard(glass: true, child: Text('row')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsNothing);
      final container = tester.widget<Container>(find.byType(Container).first);
      final decoration = container.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFF131320));
      expect(
        (decoration.border! as Border).top.color,
        const Color(0xFF38383A).withAlpha(100),
      );
    });

    testWidgets('PressableCard without glass keeps its dark pill in light '
        'mode too', (tester) async {
      ClayColors.setBrightness(Brightness.light);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PressableCard(child: Text('row'))),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(GlassSurface), findsNothing);
    });
  });
}
