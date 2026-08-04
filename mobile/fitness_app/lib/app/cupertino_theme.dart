import 'package:flutter/cupertino.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle sfText({double? fontSize, FontWeight? fontWeight, Color? color, double? letterSpacing}) {
  return GoogleFonts.inter(fontSize: fontSize, fontWeight: fontWeight, color: color, letterSpacing: letterSpacing);
}

class CupertinoAppColors {
  CupertinoAppColors._();

  static const Color background = Color(0xFF0D0D1A);
  static const Color groupedBackground = Color(0xFF14142A);
  static const Color cardElevated = Color(0xFF1C1C35);
  static const Color separator = Color(0xFF2A2A45);
  static const Color separatorOpaque = Color(0xFF353555);
  static const Color primaryBlue = Color(0xFF7C3AED);
  static const Color blueLight = Color(0xFFA78BFA);
  static const Color green = Color(0xFF22C55E);
  static const Color greenLight = Color(0xFF4ADE80);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleLight = Color(0xFFC084FC);
  static const Color neon = Color(0xFF00F5B0);
  static const Color textPrimary = Color(0xFFECECFC);
  static const Color textSecondary = Color(0xFFB4B4D0);
  static const Color textTertiary = Color(0xFF55557A);
  static const Color textQuaternary = Color(0xFF7070A0);
}

class CupertinoSpacing {
  CupertinoSpacing._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

BoxDecoration cardDecoration({
  Color? backgroundColor,
  Color? borderColor,
  double radius = 16,
  double borderWidth = 0.5,
}) {
  return BoxDecoration(
    color: backgroundColor ?? CupertinoAppColors.cardElevated,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: borderColor ?? CupertinoAppColors.separator,
      width: borderWidth,
    ),
  );
}

class CupertinoTheme {
  static CupertinoThemeData get themeData {
    return const CupertinoThemeData(
      brightness: Brightness.dark,
      primaryColor: CupertinoAppColors.purple,
      barBackgroundColor: CupertinoAppColors.groupedBackground,
      scaffoldBackgroundColor: CupertinoAppColors.background,
      textTheme: CupertinoTextThemeData(
        primaryColor: CupertinoAppColors.textPrimary,
        textStyle: TextStyle(color: CupertinoAppColors.textPrimary),
      ),
    );
  }
}
