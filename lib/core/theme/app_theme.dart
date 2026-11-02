import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Freud UI Kit'teki sıcak, sakin renk sisteminin Namaz Grubum uyarlaması.
abstract final class AppColors {
  static const seed = Color(0xFF4F3422);
  static const ink = Color(0xFF3F3C36);
  static const deepBrown = Color(0xFF372315);
  static const brown = Color(0xFF4F3422);
  static const brownSoft = Color(0xFF926247);
  static const brownPale = Color(0xFFE8DDD9);
  static const mist = Color(0xFFFFFFFF);
  static const warmWhite = Color(0xFFF7F4F2);
  static const line = Color(0xFFE8DDD9);
  static const muted = Color(0xFF736B66);
  static const green = Color(0xFF7D944D);
  static const greenSoft = Color(0xFF9BB068);
  static const greenPale = Color(0xFFE5EAD7);
  static const greenMist = Color(0xFFF2F5EB);
  static const orange = Color(0xFFED7E1C);
  static const orangePale = Color(0xFFFFE9D6);
  static const amber = Color(0xFFED7E1C);
  static const error = Color(0xFFB54B3F);
}

abstract final class AppTheme {
  static const _fontFamily = 'Urbanist';

  static final materialLight = ThemeData(
    useMaterial3: true,
    fontFamily: _fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.brown,
      brightness: Brightness.light,
      surface: AppColors.mist,
      primary: AppColors.brown,
      secondary: AppColors.green,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.warmWhite,
    canvasColor: AppColors.warmWhite,
    dividerColor: AppColors.line,
    textTheme: const TextTheme(
      displaySmall: TextStyle(
        fontSize: 36,
        height: 1.05,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: AppColors.brown,
      ),
      headlineSmall: TextStyle(
        fontSize: 26,
        height: 1.15,
        fontWeight: FontWeight.w800,
        letterSpacing: -.6,
        color: AppColors.brown,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
        color: AppColors.brown,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.brown,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.45,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.mist,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: AppColors.line, width: .7),
        borderRadius: BorderRadius.all(Radius.circular(28)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: AppColors.mist,
      hintStyle: TextStyle(
        color: Color(0xFFACA9A5),
        fontWeight: FontWeight.w500,
      ),
      prefixIconColor: AppColors.muted,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.brown, width: 1.4),
        borderRadius: BorderRadius.all(Radius.circular(22)),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.brown,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.brownPale,
        disabledForegroundColor: AppColors.brownSoft,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        minimumSize: const Size.fromHeight(56),
        shape: const StadiumBorder(),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.brown,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape: const StadiumBorder(),
      ),
    ),
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: AppColors.warmWhite,
      foregroundColor: AppColors.brown,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: _fontFamily,
        color: AppColors.brown,
        fontSize: 21,
        fontWeight: FontWeight.w800,
        letterSpacing: -.3,
      ),
    ),
  );

  static final materialDark = materialLight.copyWith(
    brightness: Brightness.light,
  );

  static const cupertinoLight = CupertinoThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.brown,
    scaffoldBackgroundColor: AppColors.warmWhite,
    barBackgroundColor: Color(0xF7F7F4F2),
    textTheme: CupertinoTextThemeData(
      primaryColor: AppColors.brown,
      textStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 16,
        fontFamily: _fontFamily,
      ),
      navTitleTextStyle: TextStyle(
        color: AppColors.brown,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        fontFamily: _fontFamily,
      ),
    ),
  );
}
