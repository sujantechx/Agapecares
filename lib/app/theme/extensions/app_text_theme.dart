import 'package:flutter/material.dart';

// A custom theme extension for text styles
class AppTextTheme extends ThemeExtension<AppTextTheme> {
  final TextStyle? h1;
  final TextStyle? h2;
  final TextStyle? subtitle1;
  final TextStyle? body;

  const AppTextTheme({
    this.h1,
    this.h2,
    this.subtitle1,
    this.body,
  });

  @override
  ThemeExtension<AppTextTheme> copyWith({
    TextStyle? h1,
    TextStyle? h2,
    TextStyle? subtitle1,
    TextStyle? body,
  }) {
    return AppTextTheme(
      h1: h1 ?? this.h1,
      h2: h2 ?? this.h2,
      subtitle1: subtitle1 ?? this.subtitle1,
      body: body ?? this.body,
    );
  }

  @override
  ThemeExtension<AppTextTheme> lerp(
      ThemeExtension<AppTextTheme>? other, double t) {
    if (other is! AppTextTheme) {
      return this;
    }
    return AppTextTheme(
      h1: TextStyle.lerp(h1, other.h1, t),
      h2: TextStyle.lerp(h2, other.h2, t),
      subtitle1: TextStyle.lerp(subtitle1, other.subtitle1, t),
      body: TextStyle.lerp(body, other.body, t),
    );
  }
}