import 'package:flutter/material.dart';

// A central place for all your app's colors
class AppColors {
  // Prevent instantiation
  AppColors._();

  // Main Palette
  static const Color primary = Color(0xFF6200EE);
  static const Color primaryVariant = Color(0xFF3700B3);
  static const Color secondary = Color(0xFF03DAC6);
  static const Color secondaryVariant = Color(0xFF018786);

  // Light Theme Specific
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightOnSecondary = Color(0xFF000000);
  static const Color lightOnBackground = Color(0xFF000000);
  static const Color lightOnSurface = Color(0xFF000000);
  static const Color lightError = Color(0xFFB00020);

  // Dark Theme Specific
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E); // A bit lighter than background
  static const Color darkOnPrimary = Color(0xFF000000);
  static const Color darkOnSecondary = Color(0xFF000000);
  static const Color darkOnBackground = Color(0xFFFFFFFF);
  static const Color darkOnSurface = Color(0xFFFFFFFF);
  static const Color darkError = Color(0xFFCF6679);
}