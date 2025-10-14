import 'package:flutter/material.dart';

// A custom theme extension for button styles
class AppButtonTheme extends ThemeExtension<AppButtonTheme> {
  final ButtonStyle? primaryButtonStyle;

  const AppButtonTheme({
    this.primaryButtonStyle,
  });

  @override
  ThemeExtension<AppButtonTheme> copyWith({
    ButtonStyle? primaryButtonStyle,
  }) {
    return AppButtonTheme(
      primaryButtonStyle: primaryButtonStyle ?? this.primaryButtonStyle,
    );
  }

  @override
  ThemeExtension<AppButtonTheme> lerp(
      ThemeExtension<AppButtonTheme>? other, double t) {
    if (other is! AppButtonTheme) {
      return this;
    }
    return this; // Lerp is not straightforward for ButtonStyle, just return current
  }
}