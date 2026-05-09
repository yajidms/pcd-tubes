import 'package:flutter/material.dart';

class AppTheme {
  // Warna Utama Aplikasi
  static const Color primaryColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF8F9FA);
  static const Color cardColor = Colors.white;

  // Palet Warna untuk Emosi
  static const Color emotionHappy   = Color(0xFFFFCA28);
  static const Color emotionSad     = Color(0xFF42A5F5);
  static const Color emotionAngry   = Color(0xFFEF5350);
  static const Color emotionFear    = Color(0xFFAB47BC);
  static const Color emotionNeutral = Color(0xFFBDBDBD);

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,

      // Konfigurasi AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20.0,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),

      // ✅ Diganti dari CardTheme → CardThemeData
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 2.0,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        margin: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      ),

      // Konfigurasi Animasi
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
}