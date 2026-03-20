import 'package:flutter/material.dart';

//  CUSTOMER  (red accent)
class CustomerColors {
  // Brand accent — same in both modes
  static const primary = Color(0xFFDC2626);
  static const primaryDark = Color(0xFFEF4444);

  // Light
  static const background = Color(0xFFFFF0F0);
  static const surface = Color(0xFFFFFFFF);
  static const textPrimary = Color(0xFF111827);
  static const textMuted = Color(0xFF6B7280);

  // Dark
  static const backgroundDark = Color(0xFF1A0808);
  static const surfaceDark = Color(0xFF2C1010);
  static const textPrimaryDark = Color(0xFFF3F4F6);
  static const textMutedDark = Color(0xFF9CA3AF);
}

ThemeData customerLightTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.light,
  scaffoldBackgroundColor: CustomerColors.background,
  primaryColor: CustomerColors.primary,
  cardColor: CustomerColors.surface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: CustomerColors.textPrimary,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: CustomerColors.surface,
    selectedItemColor: CustomerColors.primary,
    unselectedItemColor: CustomerColors.textMuted,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: CustomerColors.textPrimary),
  ),
  colorScheme: const ColorScheme.light(
    primary: CustomerColors.primary,
    surface: CustomerColors.surface,
    background: CustomerColors.background,
  ),
);

ThemeData customerDarkTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: CustomerColors.backgroundDark,
  primaryColor: CustomerColors.primaryDark,
  cardColor: CustomerColors.surfaceDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: CustomerColors.textPrimaryDark,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: CustomerColors.surfaceDark,
    selectedItemColor: CustomerColors.primaryDark,
    unselectedItemColor: CustomerColors.textMutedDark,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(color: CustomerColors.textPrimaryDark),
  ),
  colorScheme: const ColorScheme.dark(
    primary: CustomerColors.primaryDark,
    surface: CustomerColors.surfaceDark,
    background: CustomerColors.backgroundDark,
  ),
);

//  VENDOR  (teal accent)
class VendorColors {
  static const primary = Color(0xFF00B4B4);
  static const primaryDark = Color(0xFF00D4D4);
  static const amber = Color(0xFFFFC542);
  static const blue = Color(0xFF4A90E2);
  static const open = Color(0xFF00C48C);

  // Light
  static const background = Color(0xFFF0FAFA);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFE0F7F7);
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF6B8A8A);

  // Dark
  static const backgroundDark = Color(0xFF081818);
  static const surfaceDark = Color(0xFF0F2828);
  static const surfaceAltDark = Color(0xFF163535);
  static const textDark = Color(0xFFF0F0F0);
  static const mutedDark = Color(0xFF7AABAB);
}

ThemeData vendorLightTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.light,
  scaffoldBackgroundColor: VendorColors.background,
  primaryColor: VendorColors.primary,
  cardColor: VendorColors.surface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: VendorColors.text,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: VendorColors.surface,
    selectedItemColor: VendorColors.primary,
    unselectedItemColor: VendorColors.muted,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  colorScheme: const ColorScheme.light(
    primary: VendorColors.primary,
    surface: VendorColors.surface,
    background: VendorColors.background,
  ),
);

ThemeData vendorDarkTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: VendorColors.backgroundDark,
  primaryColor: VendorColors.primaryDark,
  cardColor: VendorColors.surfaceDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: VendorColors.textDark,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: VendorColors.surfaceDark,
    selectedItemColor: VendorColors.primaryDark,
    unselectedItemColor: VendorColors.mutedDark,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  colorScheme: const ColorScheme.dark(
    primary: VendorColors.primaryDark,
    surface: VendorColors.surfaceDark,
    background: VendorColors.backgroundDark,
  ),
);

//  RIDER  (orange accent)
class RiderColors {
  static const online = Color(0xFF00D97E);
  static const amber = Color(0xFFFFC542);
  static const blue = Color(0xFF4A90E2);
  static const purple = Color(0xFFB06EFF);

  // Light
  static const background = Color(0xFFFFF8F2);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFFFF0E6);
  static const text = Color(0xFF1A1A1A);
  static const muted = Color(0xFF888888);
  static const offline = Color(0xFF3A3F50);

  // Dark
  static const backgroundDark = Color(0xFF1A1208);
  static const surfaceDark = Color(0xFF2A1E0C);
  static const surfaceAltDark = Color(0xFF352410);
  static const textDark = Color(0xFFF0F0F0);
  static const mutedDark = Color(0xFFAAAAAA);
  static const offlineDark = Color(0xFF6B7280);
}

ThemeData riderLightTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.light,
  scaffoldBackgroundColor: RiderColors.background,
  primaryColor: RiderColors.online,
  cardColor: RiderColors.surface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: RiderColors.text,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: RiderColors.surface,
    selectedItemColor: RiderColors.online,
    unselectedItemColor: RiderColors.muted,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  colorScheme: const ColorScheme.light(
    primary: RiderColors.online,
    surface: RiderColors.surface,
    background: RiderColors.background,
  ),
);

ThemeData riderDarkTheme = ThemeData(
  useMaterial3: false,
  brightness: Brightness.dark,
  scaffoldBackgroundColor: RiderColors.backgroundDark,
  primaryColor: RiderColors.online,
  cardColor: RiderColors.surfaceDark,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: RiderColors.textDark,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: RiderColors.surfaceDark,
    selectedItemColor: RiderColors.online,
    unselectedItemColor: RiderColors.mutedDark,
    showUnselectedLabels: true,
    type: BottomNavigationBarType.fixed,
  ),
  colorScheme: const ColorScheme.dark(
    primary: RiderColors.online,
    surface: RiderColors.surfaceDark,
    background: RiderColors.backgroundDark,
  ),
);