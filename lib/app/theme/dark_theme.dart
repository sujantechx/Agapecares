import 'package:flutter/material.dart';
import './app_colors.dart';
import './extensions/app_button_theme.dart';
import './extensions/app_card_theme.dart';
import './extensions/app_text_theme.dart';

final darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.darkBackground,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.dark).copyWith(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryVariant,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryVariant,
    surface: AppColors.darkSurface,
    // background/onBackground are intentionally omitted to avoid deprecated fields
    error: AppColors.darkError,
    onPrimary: AppColors.darkOnPrimary,
    onSecondary: AppColors.darkOnSecondary,
    onSurface: AppColors.darkOnSurface,
    onError: AppColors.darkOnPrimary,
  ),
  extensions: [
    AppTextTheme(
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.darkOnBackground,
      ),
      h2: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkOnBackground,
      ),
      subtitle1: TextStyle(
        fontSize: 16,
        color: AppColors.darkOnBackground.withAlpha((0.7 * 255).round()),
      ),
      body: TextStyle(
        fontSize: 14,
        color: AppColors.darkOnBackground,
      ),
    ),
    const AppCardTheme(
      backgroundColor: AppColors.darkSurface,
      borderRadius: 12.0,
      elevation: 2.0,
    ),
    AppButtonTheme(
      primaryButtonStyle: ElevatedButton.styleFrom(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.darkOnSecondary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  ],
);