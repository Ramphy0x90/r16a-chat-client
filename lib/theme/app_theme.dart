import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: ZmeyColors.lightBg,
    colorScheme: const ColorScheme.light(
      surface: ZmeyColors.lightSurface,
      primary: ZmeyColors.lightAccentGold,
      secondary: ZmeyColors.lightAccentMaroon,
      onSurface: ZmeyColors.lightTextPrimary,
      onSurfaceVariant: ZmeyColors.lightTextSecondary,
    ),
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZmeyColors.darkBg,
    colorScheme: const ColorScheme.dark(
      surface: ZmeyColors.darkSurface,
      primary: ZmeyColors.darkAccentMaroon,
      secondary: ZmeyColors.darkAccentGold,
      onSurface: ZmeyColors.darkTextPrimary,
      onSurfaceVariant: ZmeyColors.darkTextSecondary,
    ),
  );
}
