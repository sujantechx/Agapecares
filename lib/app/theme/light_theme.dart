import 'package:flutter/material.dart';
import './app_colors.dart';
import './extensions/app_button_theme.dart';
import './extensions/app_card_theme.dart';
import './extensions/app_text_theme.dart';

final lightTheme = ThemeData(
  brightness: Brightness.light,
  primaryColor: AppColors.primary,
  scaffoldBackgroundColor: AppColors.lightBackground,
  colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: Brightness.light).copyWith(
    primary: AppColors.primary,
    primaryContainer: AppColors.primaryVariant,
    secondary: AppColors.secondary,
    secondaryContainer: AppColors.secondaryVariant,
    surface: AppColors.lightSurface,
    // avoid setting background/onBackground (deprecated) - scaffoldBackgroundColor is set above
    error: AppColors.lightError,
    onPrimary: AppColors.lightOnPrimary,
    onSecondary: AppColors.lightOnSecondary,
    onSurface: AppColors.lightOnSurface,
    onError: AppColors.lightOnPrimary,
  ),
  extensions: [
    AppTextTheme(
      h1: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.lightOnBackground,
      ),
      h2: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.lightOnBackground,
      ),
      subtitle1: TextStyle(
        fontSize: 16,
        color: AppColors.lightOnBackground.withAlpha((0.7 * 255).round()),
      ),
      body: TextStyle(
        fontSize: 14,
        color: AppColors.lightOnBackground,
      ),
    ),
    const AppCardTheme(
      backgroundColor: AppColors.lightSurface,
      borderRadius: 12.0,
      elevation: 4.0,
    ),
    AppButtonTheme(
      primaryButtonStyle: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.lightOnPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    ),
  ],
);