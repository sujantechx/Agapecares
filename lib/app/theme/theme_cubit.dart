// filepath: c:\FlutterDev\agapecares\lib\app\theme\theme_cubit.dart
// Simple ThemeCubit to toggle between light, dark, and system modes globally.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeCubit persists a user's theme preference in SharedPreferences under
/// the key 'theme_mode'. Valid stored values are: 'light', 'dark', 'system'.
///
/// Behavior:
/// - On construction it asynchronously loads the saved preference and emits it
///   (defaults to ThemeMode.system when missing).
/// - `setLight()`, `setDark()`, `setSystem()` set and persist the chosen mode.
/// - `toggle()` toggles between light and dark (system -> light).
class ThemeCubit extends Cubit<ThemeMode> {
  static const _prefsKey = 'theme_mode';

  ThemeCubit() : super(ThemeMode.system) {
    _loadFromPrefs();
  }

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getString(_prefsKey);
      if (v == 'light') emit(ThemeMode.light);
      else if (v == 'dark') emit(ThemeMode.dark);
      else emit(ThemeMode.system);
    } catch (_) {
      // On error default to system
      emit(ThemeMode.system);
    }
  }

  Future<void> _save(String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, value);
    } catch (_) {
      // ignore persistence errors
    }
  }

  void setLight() {
    emit(ThemeMode.light);
    _save('light');
  }

  void setDark() {
    emit(ThemeMode.dark);
    _save('dark');
  }

  void setSystem() {
    emit(ThemeMode.system);
    _save('system');
  }

  void toggle() {
    final cur = state;
    if (cur == ThemeMode.light) setDark();
    else setLight();
  }
}
