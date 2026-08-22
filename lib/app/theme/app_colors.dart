import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Editorial Paper Palette (Light Mode)
  static const Color paperBackground = Color(0xFFFDFBF7); // Warm Cream Paper
  static const Color paperSurface = Color(0xFFF8F6F0);
  static const Color paperBorder = Color(0xFFE4E0D8); // 0.8px Thin Rules

  // Dark Editorial Slate Palette (Dark Mode)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);

  // Primary Ink & Brand Accent
  static const Color primaryInk = Color(0xFF18181B); // Deep Charcoal Ink
  static const Color primary = Color(0xFF18181B); // Alias for primaryInk
  static const Color primaryDark = Color(0xFF18181B);
  static const Color primaryAccent = Color(0xFF3730A3); // Deep Indigo
  static const Color primaryLight = Color(0xFFE0E7FF);

  // Compatibility aliases
  static const Color surfaceLight = Color(0xFFF8F6F0);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFFE4E0D8);
  static const Color borderDark = Color(0xFF334155);

  // Semantic Restrained Financial Colors
  static const Color income = Color(0xFF15803D); // Restrained Emerald (+ Positive Growth)
  static const Color incomeLight = Color(0xFFDCFCE7);
  static const Color expense = Color(0xFFB91C1C); // Restrained Crimson (- Spend Index)
  static const Color expenseLight = Color(0xFFFEE2E2);

  // Status & Urgency
  static const Color warning = Color(0xFFD97706); // Amber Warning
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFDC2626); // Deep Coral Overdue
  static const Color dangerLight = Color(0xFFFEE2E2);

  // Typography Contrast
  static const Color textPrimaryLight = Color(0xFF18181B);
  static const Color textSecondaryLight = Color(0xFF52525B);
  static const Color textMutedLight = Color(0xFF71717A);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFFA1A1AA);
  static const Color textMutedDark = Color(0xFF71717A);
}
