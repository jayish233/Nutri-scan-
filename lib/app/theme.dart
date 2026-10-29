import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// NutriScan tokens from the design pack (nutriscan-flutter-cursor-pack/lib/core/theme/app_tokens.dart):
/// pure black canvas, lime for actions, one fixed colour per nutrient. Light values follow DESIGN.md.
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.canvas,
    required this.card,
    required this.cardElevated,
    required this.primaryText,
    required this.secondaryText,
    required this.hairline,
    required this.brandDeep,
  });

  final Color canvas, card, cardElevated, primaryText, secondaryText, hairline, brandDeep;

  static const brand = Color(0xFFC9FF3D);
  static const ink = Color(0xFF000000); // text and icons on lime
  static const muted = Color(0xFFA1A1A6); // secondary text on the always-dark auth screens
  static const outline = Color(0xFF636366); // Android outlined fields and buttons
  // One colour per nutrient. Never recolour these to match the brand.
  static const energy = Color(0xFFFA114F);
  static const protein = Color(0xFFBF5AF2);
  static const carbs = Color(0xFFFFD60A);
  static const fat = Color(0xFF64D2FF);
  static const fiber = Color(0xFF30D158);
  static const success = fiber;
  static const errorText = Color(0xFFFF8C80);

  static const dark = AppColors(
    canvas: Color(0xFF000000),
    card: Color(0xFF1C1C1E),
    cardElevated: Color(0xFF2C2C2E),
    primaryText: Color(0xFFFFFFFF),
    secondaryText: muted,
    hairline: Color(0xFF3A3A3C),
    brandDeep: brand,
  );

  static const light = AppColors(
    canvas: Color(0xFFF2F2F7),
    card: Color(0xFFFFFFFF),
    cardElevated: Color(0xFFE5E5EA),
    primaryText: Color(0xFF000000),
    secondaryText: Color(0xFF6B6B70),
    hairline: Color(0x1A000000),
    brandDeep: Color(0xFF446600),
  );

  static AppColors of(BuildContext context) => Theme.of(context).extension<AppColors>()!;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) => t < 0.5 ? this : (other ?? this);
}

const spaceXs = 4.0, spaceS = 8.0, spaceM = 12.0, spaceL = 16.0, spaceXl = 24.0, spaceXxl = 32.0;
const radiusSmall = 10.0, radiusChip = 14.0, radiusMedium = 16.0;
const scrollBottomInset = 108.0;

/// One screen widget per screen; only the chrome differs by platform.
bool isCupertino(BuildContext context) => Theme.of(context).platform == TargetPlatform.iOS;
double cardRadius(BuildContext context) => isCupertino(context) ? 22 : 28;
double tileRadius(BuildContext context) => isCupertino(context) ? 18 : 20;

ThemeData buildTheme(Brightness brightness, [TargetPlatform? platform]) {
  final c = brightness == Brightness.dark ? AppColors.dark : AppColors.light;
  final ios = (platform ?? defaultTargetPlatform) == TargetPlatform.iOS;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: AppColors.brand,
    onPrimary: AppColors.ink,
    secondary: c.brandDeep,
    onSecondary: AppColors.ink,
    error: AppColors.energy,
    onError: Colors.white,
    surface: c.canvas,
    onSurface: c.primaryText,
    onSurfaceVariant: c.secondaryText,
    surfaceContainer: c.card,
    surfaceContainerHigh: c.card,
    surfaceContainerHighest: c.cardElevated,
    outline: ios ? c.hairline : AppColors.outline,
    outlineVariant: c.hairline,
  );
  TextStyle t(double size, FontWeight w, [Color? color]) =>
      TextStyle(fontFamily: 'Inter', fontSize: size, fontWeight: w, color: color ?? c.primaryText);
  OutlineInputBorder field(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(ios ? 14 : 12),
    borderSide: BorderSide(color: color, width: width),
  );
  final pill = ButtonStyle(
    minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
    shape: const WidgetStatePropertyAll(StadiumBorder()),
    textStyle: WidgetStatePropertyAll(t(ios ? 17 : 16, FontWeight.w600)),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    platform: platform,
    colorScheme: scheme,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: c.canvas,
    canvasColor: c.canvas,
    extensions: [c],
    textTheme: TextTheme(
      displayLarge: t(68, FontWeight.bold),
      headlineLarge: t(34, FontWeight.w800).copyWith(letterSpacing: -0.5),
      headlineMedium: t(28, FontWeight.bold),
      headlineSmall: t(22, FontWeight.bold),
      titleLarge: t(24, FontWeight.w600),
      titleMedium: t(17, FontWeight.w600),
      bodyLarge: t(17, FontWeight.normal),
      bodyMedium: t(15, FontWeight.normal),
      bodySmall: t(13, FontWeight.normal, c.secondaryText),
      labelSmall: t(12, FontWeight.bold, c.secondaryText).copyWith(letterSpacing: 0.8),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.canvas,
      foregroundColor: c.primaryText,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: ios ? t(17, FontWeight.w600) : t(22, FontWeight.w600),
    ),
    cardTheme: CardThemeData(color: c.card, elevation: 0, margin: EdgeInsets.zero),
    dividerColor: c.hairline,
    dividerTheme: DividerThemeData(color: c.hairline, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: pill.merge(FilledButton.styleFrom(backgroundColor: AppColors.brand, foregroundColor: AppColors.ink)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: pill.merge(
        OutlinedButton.styleFrom(
          foregroundColor: c.primaryText,
          side: BorderSide(color: scheme.outline),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.brandDeep, textStyle: t(15, FontWeight.w600)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.brand,
      foregroundColor: AppColors.ink,
      extendedTextStyle: t(16, FontWeight.w600, AppColors.ink),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 80,
      backgroundColor: c.card,
      indicatorColor: AppColors.brand,
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.ink : c.secondaryText),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => t(12, FontWeight.w600, s.contains(WidgetState.selected) ? c.primaryText : c.secondaryText),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? (ios ? c.cardElevated : AppColors.brand) : (ios ? c.card : null),
        ),
        foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) && !ios ? AppColors.ink : c.primaryText),
        side: WidgetStatePropertyAll(BorderSide(color: ios ? c.card : scheme.outline)),
        textStyle: WidgetStatePropertyAll(t(14, FontWeight.w600)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.cardElevated,
      selectedColor: AppColors.brand,
      checkmarkColor: AppColors.ink,
      labelStyle: t(14, FontWeight.w600),
      secondaryLabelStyle: t(14, FontWeight.w600, AppColors.ink),
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    dialogTheme: DialogThemeData(backgroundColor: c.card),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brand),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.cardElevated,
      contentTextStyle: t(15, FontWeight.w600),
      behavior: SnackBarBehavior.floating,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.brandDeep),
    // iOS: filled card-colour field with a lime border on focus. Android: outlined, 2 px lime on focus.
    inputDecorationTheme: InputDecorationTheme(
      filled: ios,
      fillColor: c.card,
      border: field(ios ? c.cardElevated : AppColors.outline),
      enabledBorder: field(ios ? c.cardElevated : AppColors.outline),
      focusedBorder: field(c.brandDeep, ios ? 1.5 : 2),
      errorBorder: field(AppColors.errorText),
      focusedErrorBorder: field(AppColors.errorText, 2),
      labelStyle: TextStyle(color: c.secondaryText),
      floatingLabelStyle: TextStyle(color: c.brandDeep),
      errorStyle: const TextStyle(color: AppColors.errorText, fontSize: 13),
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: c.canvas, showDragHandle: true),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.brand : null),
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.ink : null),
    ),
  );
}

Color metricTrack(Color metric) => metric.withValues(alpha: 0.22);
