import 'package:flutter/material.dart';

/// NutriScan design tokens. Source of truth for colours, spacing and radii.
/// Both platforms share these; only the chrome (tab bar vs navigation bar) differs.
class AppColors {
  static const brand = Color(0xFFC9FF3D); // lime: actions, active states
  static const canvas = Color(0xFF000000);
  static const card = Color(0xFF1C1C1E);
  static const raised = Color(0xFF2C2C2E); // tab bar, pills, track fills
  static const hairline = Color(0xFF3A3A3C);
  static const outline = Color(0xFF636366); // Android outlined fields and buttons
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFA1A1A6);

  // One colour per nutrient. Never recolour these to match the brand.
  static const energy = Color(0xFFFA114F);
  static const energyTrack = Color(0xFF3A0A18);
  static const protein = Color(0xFFBF5AF2);
  static const carbs = Color(0xFFFFD60A);
  static const fat = Color(0xFF64D2FF);
  static const fiber = Color(0xFF30D158);

  static const onBrand = Color(0xFF000000);
}

class AppSpacing {
  static const screen = 16.0; // horizontal page padding
  static const gap = 14.0; // between cards
  static const tileGap = 10.0;
  static const authPadding = 24.0;
}

class AppRadii {
  static const cardIos = 22.0;
  static const tileIos = 18.0;
  static const cardAndroid = 28.0;
  static const tileAndroid = 20.0;
  static const field = 14.0; // iOS fields; Android outlined fields use 12
  static const pill = 999.0;
}

ThemeData buildAppTheme() {
  const scheme = ColorScheme.dark(
    primary: AppColors.brand,
    onPrimary: AppColors.onBrand,
    surface: AppColors.canvas,
    onSurface: AppColors.textPrimary,
    surfaceContainerHigh: AppColors.card,
    surfaceContainerHighest: AppColors.raised,
    outline: AppColors.outline,
    error: AppColors.energy,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'Inter', // bundle Inter 400/600/800 under assets/fonts
    cardTheme: const CardThemeData(
      color: AppColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.onBrand,
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.raised),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.field),
        borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
      ),
    ),
  );
}
