import 'package:flutter/material.dart';

class CustomerColors {
  static const primary = Color(0xFFDC2626); // 🔴 red from HTML
  static const background = Color(0xFFFFFFFF);
  static const surface = Color(0xFFF9FAFB);
  static const textPrimary = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);
}

final ThemeData customerTheme = ThemeData(
  useMaterial3: false,
  scaffoldBackgroundColor: CustomerColors.background,
  primaryColor: CustomerColors.primary,

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: CustomerColors.textPrimary,
  ),

  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: CustomerColors.primary,
    unselectedItemColor: CustomerColors.textMuted,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),

  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: CustomerColors.textPrimary),
  ),
);
