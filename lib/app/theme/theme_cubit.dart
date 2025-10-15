// filepath: c:\FlutterDev\agapecares\lib\app\theme\theme_cubit.dart
// Simple ThemeCubit to toggle between light, dark, and system modes globally.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  // Start with system so the app follows the phone's theme by default.
  ThemeCubit() : super(ThemeMode.system);

  /// Set explicit light theme
  void setLight() => emit(ThemeMode.light);

  /// Set explicit dark theme
  void setDark() => emit(ThemeMode.dark);

  /// Follow the device/system theme
  void setSystem() => emit(ThemeMode.system);

  /// Cycle between system -> light -> dark -> system
  void toggle() {
    if (state == ThemeMode.system) {
      emit(ThemeMode.light);
    } else if (state == ThemeMode.light) {
      emit(ThemeMode.dark);
    } else {
      emit(ThemeMode.system);
    }
  }
}
