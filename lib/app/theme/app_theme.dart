import 'package:flutter/material.dart';

import 'extensions/app_button_theme.dart';
import 'extensions/app_card_theme.dart';
import 'extensions/app_text_theme.dart';
import './light_theme.dart' as _light_theme;
import './dark_theme.dart' as _dark_theme;

// Export all the theme components for easy access
export './light_theme.dart';
export './dark_theme.dart';
export './extensions/app_button_theme.dart';
export './extensions/app_card_theme.dart';
export './extensions/app_text_theme.dart';

// Helper class to easily access custom theme extensions
class AppTheme {
  // Provide convenient accessors to the concrete ThemeData instances
  // so callers can reference `AppTheme.lightTheme` / `AppTheme.darkTheme`.
  static ThemeData get lightTheme => _light_theme.lightTheme;
  static ThemeData get darkTheme => _dark_theme.darkTheme;

  static AppTextTheme textTheme(BuildContext context) =>
      Theme.of(context).extension<AppTextTheme>()!;

  static AppCardTheme cardTheme(BuildContext context) =>
      Theme.of(context).extension<AppCardTheme>()!;

  static AppButtonTheme buttonTheme(BuildContext context) =>
      Theme.of(context).extension<AppButtonTheme>()!;

  // Commonly used colors across the app. Using const so they can be
  // used in const widget expressions.
  static const Color primaryColor = Color(0xFF0A7FFF); // blue-ish
  static const Color accentColor = Color(0xFFFFA000); // amber
  static const Color subtitleColor = Color(0xFF757575); // grey
  static const Color textColor = Color(0xFF212121);
  static const Color backgroundColor = Color(0xFFF5F5F5);
}