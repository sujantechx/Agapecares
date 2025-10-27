// filepath: c:\FlutterDev\agapecares\lib\app\theme\theme_cubit.dart
// Simple ThemeCubit to toggle between light, dark, and system modes globally.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// Persisted theme preference removed: app will always follow system theme.

class ThemeCubit extends Cubit<ThemeMode> {
  // Start with system so the app follows the phone's theme by default.
  ThemeCubit() : super(ThemeMode.system);

  // No-op persistence and setter methods: always use system theme.
  void setLight() {
    // Intentionally enforce system theme; do not switch to explicit light.
    emit(ThemeMode.system);
  }

  void setDark() {
    // Intentionally enforce system theme; do not switch to explicit dark.
    emit(ThemeMode.system);
  }

  void setSystem() {
    emit(ThemeMode.system);
  }

  void toggle() {
    // No-op toggle: keep following the system.
    emit(ThemeMode.system);
  }
}
