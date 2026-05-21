import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ──────────────────────────────────────────────────────────────────────────────
// AppTheme — Tim CAP Dark Camera Theme
// Palet: Hitam matte background, aksen neon hijau, tipografi Inter/system
// ──────────────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  // Warna primer
  static const Color primary = Color(0xFF00E676);       // neon green
  static const Color background = Color(0xFF0A0A0A);    // near-black
  static const Color surface = Color(0xFF141414);       // card surface
  static const Color surfaceVariant = Color(0xFF1E1E1E);
  static const Color onBackground = Color(0xFFEEEEEE);
  static const Color onSurface = Color(0xFFCCCCCC);
  static const Color accent = Color(0xFF00BCD4);        // cyan accent

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accent,
        surface: surface,
        onPrimary: Colors.black,
        onSecondary: Colors.black,
        onSurface: onBackground,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        foregroundColor: onBackground,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: onBackground,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: onBackground,
        ),
        bodyMedium: TextStyle(fontSize: 14, color: onSurface),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: onSurface,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: primary,
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
    );
  }

  // Tetap ada lightTheme agar tidak break import lama
  static ThemeData get lightTheme => darkTheme;
}
