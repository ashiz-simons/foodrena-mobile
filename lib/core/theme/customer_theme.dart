import 'package:flutter/material.dart';

class CustomerColors {
  static const primary = Color(0xFFDC2626); // 🔴 red
  static const background = Color(0xFFFFF0F0); // milky red background
  static const surface = Color(0xFFFFFFFF);    // white for cards/tabs
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