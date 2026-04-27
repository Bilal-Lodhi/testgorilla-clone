import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF0F172A);
  static const Color secondaryColor = Color(0xFF2563EB);
  static const Color accentColor = Color(0xFF0EA5E9);
  static const Color successColor = Color(0xFF16A34A);
  static const Color warningColor = Color(0xFFEA580C);
  static const Color errorColor = Color(0xFFDC2626);
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF8FAFC);
  static const Color backgroundColor = Color(0xFFF3F6FB);
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: secondaryColor,
      secondary: accentColor,
      tertiary: primaryColor,
      error: errorColor,
      surface: surfaceColor,
      onPrimary: Colors.white,
      onSurface: Color(0xFF0B1220),
    );

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(radiusMd),
      borderSide: const BorderSide(color: Color(0xFFD8DFEA), width: 1),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Color(0xFF0B1220),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: secondaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: Color(0xFFD1D9E8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: secondaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: outlineBorder,
        enabledBorder: outlineBorder,
        focusedBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: secondaryColor, width: 1.5),
        ),
        errorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: errorColor, width: 1.2),
        ),
        focusedErrorBorder: outlineBorder.copyWith(
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        helperStyle: const TextStyle(fontSize: 12),
        errorStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        selectedColor: secondaryColor.withOpacity(0.12),
      ),
      dividerColor: const Color(0xFFE2E8F0),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45),
        bodySmall: TextStyle(fontSize: 12, height: 1.4),
      ),
    );
  }
}
