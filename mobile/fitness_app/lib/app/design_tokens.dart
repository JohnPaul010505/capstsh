import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ClayColors {
  ClayColors._();

  // Light Clay Theme (Primary)
  static const Color clayBase = Color(0xFFF4F1FA);
  static const Color claySurface = Color(0xFFFFFFFF);
  static const Color claySurfaceElevated = Color(0xFFFDFBFF);
  static const Color clayCard = Color(0xFFFFFFFF);
  static const Color clayCardHover = Color(0xFFFAF8FC);

  // Brand Colors
  static const Color clayPrimary = Color(0xFF7C3AED);
  static const Color clayPrimaryLight = Color(0xFFA78BFA);
  static const Color clayPrimaryDark = Color(0xFF6D28D9);
  static const Color claySecondary = Color(0xFFDB2777);
  static const Color claySecondaryLight = Color(0xFFF0ABFC);
  static const Color clayAccent = Color(0xFF10B981);
  static const Color clayAccentLight = Color(0xFF6EE7B7);
  static const Color clayWarning = Color(0xFFF59E0B);
  static const Color clayWarningLight = Color(0xFFFDE68A);
  static const Color clayError = Color(0xFFEF4444);
  static const Color clayErrorLight = Color(0xFFFCA5A5);

  // Text Colors
  static const Color clayTextPrimary = Color(0xFF332F3A);
  static const Color clayTextSecondary = Color(0xFF635F69);
  static const Color clayTextTertiary = Color(0xFF8A8590);
  static const Color clayTextInverse = Color(0xFFFFFFFF);
  static const Color clayTextOnPrimary = Color(0xFFFFFFFF);

  // Border & Divider
  static const Color clayBorder = Color(0xFFE8E4ED);
  static const Color clayBorderStrong = Color(0xFFD8D4DD);
  static const Color clayDivider = Color(0xFFEDE9EF);

  // Shadow Colors (Claymorphism dual shadows)
  static const Color clayShadowLight = Color(0xFFFFFFFF);
  static const Color clayShadowDark = Color(0xFFA096B4);

  // Dark Mode (Soft UI Evolution - not pure Claymorphism)
  static const Color clayDarkBase = Color(0xFF0D0D1A);
  static const Color clayDarkSurface = Color(0xFF14142A);
  static const Color clayDarkSurfaceElevated = Color(0xFF1C1C35);
  static const Color clayDarkCard = Color(0xFF1C1C35);
  static const Color clayDarkCardHover = Color(0xFF242445);

  static const Color clayDarkTextPrimary = Color(0xFFECECFC);
  static const Color clayDarkTextSecondary = Color(0xFFB4B4D0);
  static const Color clayDarkTextTertiary = Color(0xFF7070A0);
  static const Color clayDarkTextInverse = Color(0xFF0D0D1A);

  static const Color clayDarkBorder = Color(0xFF2A2A45);
  static const Color clayDarkBorderStrong = Color(0xFF353555);
  static const Color clayDarkDivider = Color(0xFF2A2A45);

  static const Color clayDarkShadowDark = Color(0x1E000000);
  static const Color clayDarkShadowLight = Color(0x0AFFFFFF);
}

class ClaySpacing {
  ClaySpacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
  static const double pageHorizontal = 16;
  static const double pageHorizontalLarge = 24;
}

class ClayRadius {
  ClayRadius._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double round = 999;
  static const double button = 20;
  static const double card = 32;
  static const double cardInner = 24;
  static const double outer = 50;
}

class ClayElevation {
  ClayElevation._();

  static List<BoxShadow> get level0 => [];

  static List<BoxShadow> get level1 => [
    BoxShadow(
      color: ClayColors.clayShadowDark.withAlpha(30),
      offset: const Offset(4, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayShadowLight.withAlpha(150),
      offset: const Offset(-4, -4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get level2 => [
    BoxShadow(
      color: ClayColors.clayShadowDark.withAlpha(40),
      offset: const Offset(8, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayShadowLight.withAlpha(180),
      offset: const Offset(-8, -8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get level3 => [
    BoxShadow(
      color: ClayColors.clayShadowDark.withAlpha(50),
      offset: const Offset(12, 12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayShadowLight.withAlpha(200),
      offset: const Offset(-12, -12),
      blurRadius: 24,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get pressed => [
    BoxShadow(
      color: ClayColors.clayShadowDark.withAlpha(40),
      offset: const Offset(4, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayShadowLight.withAlpha(80),
      offset: const Offset(-4, -4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get darkLevel0 => [];

  static List<BoxShadow> get darkLevel1 => [
    BoxShadow(
      color: ClayColors.clayDarkShadowDark,
      offset: const Offset(0, 2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayDarkShadowLight,
      offset: const Offset(0, -1),
      blurRadius: 2,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get darkLevel2 => [
    BoxShadow(
      color: ClayColors.clayDarkShadowDark,
      offset: const Offset(0, 4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayDarkShadowDark,
      offset: const Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayDarkShadowLight,
      offset: const Offset(0, -2),
      blurRadius: 4,
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> get darkLevel3 => [
    BoxShadow(
      color: ClayColors.clayDarkShadowDark,
      offset: const Offset(0, 8),
      blurRadius: 16,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayDarkShadowDark,
      offset: const Offset(0, 16),
      blurRadius: 32,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: ClayColors.clayDarkShadowLight,
      offset: const Offset(0, -4),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];
}

class ClayTypography {
  ClayTypography._();

  static String get headingFamily => GoogleFonts.nunito().fontFamily!;
  static String get bodyFamily => GoogleFonts.dmSans().fontFamily!;

  static TextStyle get displayLarge => GoogleFonts.nunito(
    fontSize: 48, fontWeight: FontWeight.w900, color: ClayColors.clayTextPrimary,
    letterSpacing: -0.5, height: 1.1,
  );
  static TextStyle get displayMedium => GoogleFonts.nunito(
    fontSize: 36, fontWeight: FontWeight.w800, color: ClayColors.clayTextPrimary,
    letterSpacing: -0.3, height: 1.2,
  );
  static TextStyle get displaySmall => GoogleFonts.nunito(
    fontSize: 28, fontWeight: FontWeight.w800, color: ClayColors.clayTextPrimary,
    letterSpacing: -0.2, height: 1.2,
  );
  static TextStyle get headlineLarge => GoogleFonts.nunito(
    fontSize: 24, fontWeight: FontWeight.w700, color: ClayColors.clayTextPrimary,
    letterSpacing: -0.1, height: 1.3,
  );
  static TextStyle get headlineMedium => GoogleFonts.nunito(
    fontSize: 20, fontWeight: FontWeight.w700, color: ClayColors.clayTextPrimary,
    letterSpacing: 0, height: 1.3,
  );
  static TextStyle get headlineSmall => GoogleFonts.nunito(
    fontSize: 18, fontWeight: FontWeight.w600, color: ClayColors.clayTextPrimary,
    letterSpacing: 0, height: 1.4,
  );
  static TextStyle get titleLarge => GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w700, color: ClayColors.clayTextPrimary,
    letterSpacing: 0, height: 1.4,
  );
  static TextStyle get titleMedium => GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w600, color: ClayColors.clayTextPrimary,
    letterSpacing: 0.1, height: 1.4,
  );
  static TextStyle get titleSmall => GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w600, color: ClayColors.clayTextSecondary,
    letterSpacing: 0.2, height: 1.4,
  );
  static TextStyle get bodyLarge => GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: ClayColors.clayTextPrimary,
    letterSpacing: -0.1, height: 1.5,
  );
  static TextStyle get bodyMedium => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: ClayColors.clayTextPrimary,
    letterSpacing: 0, height: 1.5,
  );
  static TextStyle get bodySmall => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w400, color: ClayColors.clayTextSecondary,
    letterSpacing: 0.1, height: 1.5,
  );
  static TextStyle get labelLarge => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: ClayColors.clayTextPrimary,
    letterSpacing: 0.1, height: 1.4,
  );
  static TextStyle get labelMedium => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w500, color: ClayColors.clayTextSecondary,
    letterSpacing: 0.2, height: 1.4,
  );
  static TextStyle get labelSmall => GoogleFonts.dmSans(
    fontSize: 10, fontWeight: FontWeight.w500, color: ClayColors.clayTextTertiary,
    letterSpacing: 0.3, height: 1.4,
  );

  static TextStyle get darkDisplayLarge => GoogleFonts.nunito(
    fontSize: 48, fontWeight: FontWeight.w900, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: -0.5, height: 1.1,
  );
  static TextStyle get darkDisplayMedium => GoogleFonts.nunito(
    fontSize: 36, fontWeight: FontWeight.w800, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: -0.3, height: 1.2,
  );
  static TextStyle get darkDisplaySmall => GoogleFonts.nunito(
    fontSize: 28, fontWeight: FontWeight.w800, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: -0.2, height: 1.2,
  );
  static TextStyle get darkHeadlineLarge => GoogleFonts.nunito(
    fontSize: 24, fontWeight: FontWeight.w700, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: -0.1, height: 1.3,
  );
  static TextStyle get darkHeadlineMedium => GoogleFonts.nunito(
    fontSize: 20, fontWeight: FontWeight.w700, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0, height: 1.3,
  );
  static TextStyle get darkHeadlineSmall => GoogleFonts.nunito(
    fontSize: 18, fontWeight: FontWeight.w600, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0, height: 1.4,
  );
  static TextStyle get darkTitleLarge => GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w700, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0, height: 1.4,
  );
  static TextStyle get darkTitleMedium => GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w600, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0.1, height: 1.4,
  );
  static TextStyle get darkTitleSmall => GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w600, color: ClayColors.clayDarkTextSecondary,
    letterSpacing: 0.2, height: 1.4,
  );
  static TextStyle get darkBodyLarge => GoogleFonts.dmSans(
    fontSize: 16, fontWeight: FontWeight.w400, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: -0.1, height: 1.5,
  );
  static TextStyle get darkBodyMedium => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w400, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0, height: 1.5,
  );
  static TextStyle get darkBodySmall => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w400, color: ClayColors.clayDarkTextSecondary,
    letterSpacing: 0.1, height: 1.5,
  );
  static TextStyle get darkLabelLarge => GoogleFonts.dmSans(
    fontSize: 14, fontWeight: FontWeight.w500, color: ClayColors.clayDarkTextPrimary,
    letterSpacing: 0.1, height: 1.4,
  );
  static TextStyle get darkLabelMedium => GoogleFonts.dmSans(
    fontSize: 12, fontWeight: FontWeight.w500, color: ClayColors.clayDarkTextSecondary,
    letterSpacing: 0.2, height: 1.4,
  );
  static TextStyle get darkLabelSmall => GoogleFonts.dmSans(
    fontSize: 10, fontWeight: FontWeight.w500, color: ClayColors.clayDarkTextTertiary,
    letterSpacing: 0.3, height: 1.4,
  );
}

class ClayAnimation {
  ClayAnimation._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 400);

  static const Curve easeOut = Curves.easeOutCubic;
  static const Curve easeInOut = Curves.easeInOutCubic;
  static const Curve spring = Curves.elasticOut;
  static const Curve press = Curves.easeInOut;
}

class ClayBreakpoints {
  ClayBreakpoints._();
  static const double phoneSmall = 360;
  static const double phoneMedium = 390;
  static const double phoneLarge = 430;
  static const double tabletPortrait = 600;
  static const double tabletLandscape = 840;
  static const double desktop = 1024;
  static const double desktopLarge = 1440;
}

class ClayTokens {
  ClayTokens._();

  // Direct static getters for convenient access (e.g., ClayTokens.clayPrimary, ClayTokens.md)
  // Colors
  static Color get clayBase => ClayColors.clayBase;
  static Color get claySurface => ClayColors.claySurface;
  static Color get claySurfaceElevated => ClayColors.claySurfaceElevated;
  static Color get clayCard => ClayColors.clayCard;
  static Color get clayCardHover => ClayColors.clayCardHover;
  static Color get clayPrimary => ClayColors.clayPrimary;
  static Color get clayPrimaryLight => ClayColors.clayPrimaryLight;
  static Color get clayPrimaryDark => ClayColors.clayPrimaryDark;
  static Color get claySecondary => ClayColors.claySecondary;
  static Color get claySecondaryLight => ClayColors.claySecondaryLight;
  static Color get clayAccent => ClayColors.clayAccent;
  static Color get clayAccentLight => ClayColors.clayAccentLight;
  static Color get clayWarning => ClayColors.clayWarning;
  static Color get clayWarningLight => ClayColors.clayWarningLight;
  static Color get clayError => ClayColors.clayError;
  static Color get clayErrorLight => ClayColors.clayErrorLight;
  static Color get clayTextPrimary => ClayColors.clayTextPrimary;
  static Color get clayTextSecondary => ClayColors.clayTextSecondary;
  static Color get clayTextTertiary => ClayColors.clayTextTertiary;
  static Color get clayTextInverse => ClayColors.clayTextInverse;
  static Color get clayTextOnPrimary => ClayColors.clayTextOnPrimary;
  static Color get clayBorder => ClayColors.clayBorder;
  static Color get clayBorderStrong => ClayColors.clayBorderStrong;
  static Color get clayDivider => ClayColors.clayDivider;
  static Color get clayShadowLight => ClayColors.clayShadowLight;
  static Color get clayShadowDark => ClayColors.clayShadowDark;
  static Color get clayDarkBase => ClayColors.clayDarkBase;
  static Color get clayDarkSurface => ClayColors.clayDarkSurface;
  static Color get clayDarkSurfaceElevated => ClayColors.clayDarkSurfaceElevated;
  static Color get clayDarkCard => ClayColors.clayDarkCard;
  static Color get clayDarkCardHover => ClayColors.clayDarkCardHover;
  static Color get clayDarkTextPrimary => ClayColors.clayDarkTextPrimary;
  static Color get clayDarkTextSecondary => ClayColors.clayDarkTextSecondary;
  static Color get clayDarkTextTertiary => ClayColors.clayDarkTextTertiary;
  static Color get clayDarkTextInverse => ClayColors.clayDarkTextInverse;

  static Color get clayDarkBorder => ClayColors.clayDarkBorder;
  static Color get clayDarkBorderStrong => ClayColors.clayDarkBorderStrong;
  static Color get clayDarkDivider => ClayColors.clayDarkDivider;
  static Color get clayDarkShadowDark => ClayColors.clayDarkShadowDark;
  static Color get clayDarkShadowLight => ClayColors.clayDarkShadowLight;

  // Spacing
  static double get xxs => ClaySpacing.xxs;
  static double get xs => ClaySpacing.xs;
  static double get sm => ClaySpacing.sm;
  static double get md => ClaySpacing.md;
  static double get lg => ClaySpacing.lg;
  static double get xl => ClaySpacing.xl;
  static double get xxl => ClaySpacing.xxl;
  static double get xxxl => ClaySpacing.xxxl;
  static double get pageHorizontal => ClaySpacing.pageHorizontal;
  static double get pageHorizontalLarge => ClaySpacing.pageHorizontalLarge;

  // Radius
  static double get radiusXs => ClayRadius.xs;
  static double get radiusSm => ClayRadius.sm;
  static double get radiusMd => ClayRadius.md;
  static double get radiusLg => ClayRadius.lg;
  static double get radiusXl => ClayRadius.xl;
  static double get radiusXxl => ClayRadius.xxl;
  static double get radiusRound => ClayRadius.round;
  static double get radiusButton => ClayRadius.button;
  static double get radiusCard => ClayRadius.card;
  static double get radiusCardInner => ClayRadius.cardInner;
  static double get radiusOuter => ClayRadius.outer;
  static double get radiusPill => ClayRadius.round;

  // Elevation
  static List<BoxShadow> get level0 => ClayElevation.level0;
  static List<BoxShadow> get level1 => ClayElevation.level1;
  static List<BoxShadow> get level2 => ClayElevation.level2;
  static List<BoxShadow> get level3 => ClayElevation.level3;
  static List<BoxShadow> get pressed => ClayElevation.pressed;
  static List<BoxShadow> get darkLevel0 => ClayElevation.darkLevel0;
  static List<BoxShadow> get darkLevel1 => ClayElevation.darkLevel1;
  static List<BoxShadow> get darkLevel2 => ClayElevation.darkLevel2;
  static List<BoxShadow> get darkLevel3 => ClayElevation.darkLevel3;

  // Typography
  static TextStyle get displayLarge => ClayTypography.displayLarge;
  static TextStyle get displayMedium => ClayTypography.displayMedium;
  static TextStyle get displaySmall => ClayTypography.displaySmall;
  static TextStyle get headlineLarge => ClayTypography.headlineLarge;
  static TextStyle get headlineMedium => ClayTypography.headlineMedium;
  static TextStyle get headlineSmall => ClayTypography.headlineSmall;
  static TextStyle get titleLarge => ClayTypography.titleLarge;
  static TextStyle get titleMedium => ClayTypography.titleMedium;
  static TextStyle get titleSmall => ClayTypography.titleSmall;
  static TextStyle get bodyLarge => ClayTypography.bodyLarge;
  static TextStyle get bodyMedium => ClayTypography.bodyMedium;
  static TextStyle get bodySmall => ClayTypography.bodySmall;
  static TextStyle get labelLarge => ClayTypography.labelLarge;
  static TextStyle get labelMedium => ClayTypography.labelMedium;
  static TextStyle get labelSmall => ClayTypography.labelSmall;

  static TextStyle get darkDisplayLarge => ClayTypography.darkDisplayLarge;
  static TextStyle get darkDisplayMedium => ClayTypography.darkDisplayMedium;
  static TextStyle get darkDisplaySmall => ClayTypography.darkDisplaySmall;
  static TextStyle get darkHeadlineLarge => ClayTypography.darkHeadlineLarge;
  static TextStyle get darkHeadlineMedium => ClayTypography.darkHeadlineMedium;
  static TextStyle get darkHeadlineSmall => ClayTypography.darkHeadlineSmall;
  static TextStyle get darkTitleLarge => ClayTypography.darkTitleLarge;
  static TextStyle get darkTitleMedium => ClayTypography.darkTitleMedium;
  static TextStyle get darkTitleSmall => ClayTypography.darkTitleSmall;
  static TextStyle get darkBodyLarge => ClayTypography.darkBodyLarge;
  static TextStyle get darkBodyMedium => ClayTypography.darkBodyMedium;
  static TextStyle get darkBodySmall => ClayTypography.darkBodySmall;
  static TextStyle get darkLabelLarge => ClayTypography.darkLabelLarge;
  static TextStyle get darkLabelMedium => ClayTypography.darkLabelMedium;
  static TextStyle get darkLabelSmall => ClayTypography.darkLabelSmall;

  // Animation
  static Duration get fast => ClayAnimation.fast;
  static Duration get normal => ClayAnimation.normal;
  static Duration get slow => ClayAnimation.slow;
  static Duration get slower => ClayAnimation.slower;
  static Curve get easeOut => ClayAnimation.easeOut;
  static Curve get easeInOut => ClayAnimation.easeInOut;
  static Curve get spring => ClayAnimation.spring;
  static Curve get press => ClayAnimation.press;

  // Breakpoints
  static double get phoneSmall => ClayBreakpoints.phoneSmall;
  static double get phoneMedium => ClayBreakpoints.phoneMedium;
  static double get phoneLarge => ClayBreakpoints.phoneLarge;
  static double get tabletPortrait => ClayBreakpoints.tabletPortrait;
  static double get tabletLandscape => ClayBreakpoints.tabletLandscape;
  static double get desktop => ClayBreakpoints.desktop;
  static double get desktopLarge => ClayBreakpoints.desktopLarge;

  // Convenience getters (legacy)
  static Color get primary => clayPrimary;
  static Color get secondary => claySecondary;
  static Color get accent => clayAccent;
  static Color get warning => clayWarning;
  static Color get error => clayError;
  static Color get surface => claySurface;
  static Color get card => clayCard;
  static Color get textPrimary => clayTextPrimary;
  static Color get textSecondary => clayTextSecondary;
  static Color get textTertiary => clayTextTertiary;
  static double get spacingMd => md;
  static double get spacingLg => lg;
}