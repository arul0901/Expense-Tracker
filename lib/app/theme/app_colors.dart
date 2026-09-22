import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Premium Modern Palette (Light Mode)
  static const Color paperBackground = Color(0xFFF8FAFC); // Very light blue-grey
  static const Color paperSurface = Color(0xFFFFFFFF); // Pure white cards
  static const Color paperBorder = Color(0xFFF1F5F9); // Very subtle borders

  // Dark Palette (Dark Mode)
  static const Color darkBackground = Color(0xFF0F172A);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);

  // Primary Accent (Vibrant Blue/Indigo from reference)
  static const Color primaryInk = Color(0xFF3B82F6); // Softer blue
  static const Color primary = Color(0xFF3B82F6); 
  static const Color primaryDark = Color(0xFF3B82F6);
  static const Color primaryAccent = Color(0xFF60A5FA); // Lighter accent
  static const Color primaryLight = Color(0xFFEFF6FF); // Very light blue for chips

  // Compatibility aliases
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderDark = Color(0xFF334155);

  // Semantic Colors (Income/Expense/Status)
  static const Color income = Color(0xFF22C55E); // Vibrant Green
  static const Color incomeLight = Color(0xFFDCFCE7);
  static const Color expense = Color(0xFFEF4444); // Vibrant Red
  static const Color expenseLight = Color(0xFFFEE2E2);

  // Status & Urgency
  static const Color warning = Color(0xFFF59E0B); // Amber Warning
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444); // Same as expense
  static const Color dangerLight = Color(0xFFFEE2E2);

  // Typography Contrast
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textMutedLight = Color(0xFF94A3B8);

  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textMutedDark = Color(0xFF64748B);
}
