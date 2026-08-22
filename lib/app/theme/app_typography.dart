import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  static const String fontSans = 'Roboto';

  static TextTheme textTheme(Color primaryColor, Color secondaryColor) {
    return TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: primaryColor,
      ),
      displayMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.6,
        color: primaryColor,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 22,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.4,
        color: primaryColor,
      ),
      titleLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: primaryColor,
      ),
      titleMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      titleSmall: TextStyle(
        fontFamily: fontSans,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: primaryColor,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: primaryColor,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontSans,
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      bodySmall: TextStyle(
        fontFamily: fontSans,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: secondaryColor,
      ),
      labelLarge: TextStyle(
        fontFamily: fontSans,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: primaryColor,
      ),
      labelSmall: TextStyle(
        fontFamily: fontSans,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: secondaryColor,
      ),
    );
  }
}
