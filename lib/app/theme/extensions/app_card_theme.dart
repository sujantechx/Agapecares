import 'package:flutter/material.dart';

// A custom theme extension for card/container styles
class AppCardTheme extends ThemeExtension<AppCardTheme> {
  final Color? backgroundColor;
  final double? borderRadius;
  final double? elevation;

  const AppCardTheme({
    this.backgroundColor,
    this.borderRadius,
    this.elevation,
  });

  @override
  ThemeExtension<AppCardTheme> copyWith({
    Color? backgroundColor,
    double? borderRadius,
    double? elevation,
  }) {
    return AppCardTheme(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
    );
  }

  @override
  ThemeExtension<AppCardTheme> lerp(
      ThemeExtension<AppCardTheme>? other, double t) {
    if (other is! AppCardTheme) {
      return this;
    }
    return AppCardTheme(
      backgroundColor: Color.lerp(backgroundColor, other.backgroundColor, t),
      borderRadius: t < 0.5 ? borderRadius : other.borderRadius,
      elevation: t < 0.5 ? elevation : other.elevation,
    );
  }
}