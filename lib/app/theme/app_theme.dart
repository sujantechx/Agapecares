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
}