import 'package:flutter/material.dart';

class AppTheme {
  // Gen-Z Palette
  static const Color background = Color(0xFF050505); // Deep Dark
  static const Color surface = Color(0xFF18181B); // Zinc 900
  static const Color primary = Color(0xFFCCFF00); // Neon Lime
  static const Color secondary = Color(0xFF7000FF); // Electric Purple
  static const Color textPrimary = Color(0xFFFAFAFA); // Off-white
  static const Color textSecondary = Color(0xFFA1A1AA); // Zinc 400
  static const Color error = Color(0xFFFF0055); // Hot Pink Error

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF9EFF00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        error: error,
        onPrimary: Colors.black, // Dark text on Neon Lime
        onSurface: textPrimary,
      ),
      textTheme: ThemeData.dark().textTheme
          .apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
            fontFamily: 'Plus Jakarta Sans',
          )
          .copyWith(
            displayLarge: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            headlineMedium: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
            titleLarge: const TextStyle(
              fontFamily: 'Space Grotesk',
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Space Grotesk',
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        elevation: 0,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: textSecondary,
          fontSize: 14,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          color: textSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black, // Black text on neon
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Space Grotesk',
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          elevation: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.black;
          }
          return textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return surface;
        }),
      ),
    );
  }
}
