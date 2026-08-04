import 'package:flutter/material.dart';

import 'design_tokens.dart';

final ThemeData clayThemeData = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: ClayTokens.clayPrimary,
    onPrimary: ClayTokens.clayTextInverse,
    primaryContainer: ClayTokens.clayPrimary.withAlpha(40),
    onPrimaryContainer: ClayTokens.clayPrimaryLight,
    secondary: ClayTokens.claySecondary,
    onSecondary: Colors.white,
    error: ClayTokens.clayError,
    onError: Colors.white,
    errorContainer: ClayTokens.clayError.withAlpha(40),
    onErrorContainer: ClayTokens.clayError,
    surface: ClayTokens.clayDarkBase,
    onSurface: ClayTokens.clayDarkTextPrimary,
    onSurfaceVariant: ClayTokens.clayDarkTextSecondary,
    outline: ClayTokens.clayDarkBorder,
    outlineVariant: ClayTokens.clayDarkBorderStrong,
  ),
  scaffoldBackgroundColor: ClayTokens.clayDarkBase,
  appBarTheme: AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0.5,
    centerTitle: false,
    titleTextStyle: ClayTokens.darkTitleLarge,
    iconTheme: IconThemeData(color: ClayTokens.clayDarkTextPrimary),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: ClayTokens.clayDarkSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
      borderSide: BorderSide(color: ClayTokens.clayDarkBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
      borderSide: BorderSide(color: ClayTokens.clayDarkBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
      borderSide: BorderSide(color: ClayTokens.clayPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
      borderSide: BorderSide(color: ClayTokens.clayError),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
      borderSide: BorderSide(color: ClayTokens.clayError, width: 1.5),
    ),
    contentPadding: EdgeInsets.symmetric(horizontal: ClayTokens.md, vertical: ClayTokens.sm),
    labelStyle: ClayTokens.darkBodyMedium,
    hintStyle: ClayTokens.darkBodySmall,
    errorStyle: ClayTokens.darkLabelSmall.copyWith(color: ClayTokens.clayError),
  ),
  textTheme: TextTheme(
    displayLarge: ClayTokens.darkDisplayLarge,
    displayMedium: ClayTokens.darkDisplayMedium,
    displaySmall: ClayTokens.darkDisplaySmall,
    headlineLarge: ClayTokens.darkHeadlineLarge,
    headlineMedium: ClayTokens.darkHeadlineMedium,
    headlineSmall: ClayTokens.darkHeadlineSmall,
    titleLarge: ClayTokens.darkTitleLarge,
    titleMedium: ClayTokens.darkTitleMedium,
    titleSmall: ClayTokens.darkTitleSmall,
    bodyLarge: ClayTokens.darkBodyLarge,
    bodyMedium: ClayTokens.darkBodyMedium,
    bodySmall: ClayTokens.darkBodySmall,
    labelLarge: ClayTokens.darkLabelLarge,
    labelMedium: ClayTokens.darkLabelMedium,
    labelSmall: ClayTokens.darkLabelSmall,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: ClayTokens.clayPrimary,
      foregroundColor: ClayTokens.clayTextOnPrimary,
      elevation: 0,
      padding: EdgeInsets.symmetric(horizontal: ClayTokens.xl, vertical: ClayTokens.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ClayTokens.radiusButton),
      ),
      textStyle: ClayTokens.darkTitleMedium,
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.pressed)) {
          return Colors.black.withAlpha(30);
        }
        if (states.contains(WidgetState.hovered)) {
          return Colors.black.withAlpha(15);
        }
        return null;
      }),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: ClayTokens.clayPrimaryLight,
      textStyle: ClayTokens.darkBodyLarge,
    ),
  ),
  cardTheme: CardThemeData(
    color: ClayTokens.clayDarkSurface,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusCard),
    ),
    margin: EdgeInsets.zero,
    shadowColor: Colors.transparent,
  ),
  dividerTheme: DividerThemeData(
    color: ClayTokens.clayDarkDivider.withAlpha(80),
    thickness: 0.5,
    space: 0,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: ClayTokens.clayDarkBase,
    indicatorColor: ClayTokens.clayPrimary.withAlpha(35),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return ClayTokens.darkLabelMedium.copyWith(color: ClayTokens.clayPrimaryLight);
      }
      return ClayTokens.darkLabelSmall;
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return IconThemeData(color: ClayTokens.clayPrimaryLight, size: 20);
      }
      return IconThemeData(color: ClayTokens.clayDarkTextTertiary, size: 20);
    }),
    height: 66,
    elevation: 0,
    overlayColor: WidgetStateProperty.all(Colors.transparent),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: ClayTokens.clayDarkSurfaceElevated,
    contentTextStyle: ClayTokens.darkBodyMedium,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusSm),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: ClayTokens.clayDarkSurface,
    labelStyle: ClayTokens.darkLabelMedium,
    side: BorderSide(color: ClayTokens.clayDarkBorderStrong),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  ),
  bottomSheetTheme: BottomSheetThemeData(
    backgroundColor: ClayTokens.clayDarkSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(ClayTokens.radiusLg),
      ),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: ClayTokens.clayDarkSurface,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ClayTokens.radiusMd),
    ),
  ),
);
