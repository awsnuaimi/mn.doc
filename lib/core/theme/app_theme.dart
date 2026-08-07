import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  const AppTheme._();

  static ThemeData light = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.light,
  );

  static ThemeData dark = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: Brightness.dark,
  );
}