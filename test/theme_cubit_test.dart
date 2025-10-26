import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:agapecares/app/theme/theme_cubit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ThemeCubit loads "system" when no pref set', () async {
    SharedPreferences.setMockInitialValues({}); // no pref
    final cubit = ThemeCubit();
    // Wait a tick for async load
    await Future.delayed(const Duration(milliseconds: 50));
    expect(cubit.state, ThemeMode.system);
    cubit.close();
  });

  test('ThemeCubit loads saved light mode and persists changes', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
    final cubit = ThemeCubit();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(cubit.state, ThemeMode.light);

    // toggle should move to dark and persist
    cubit.toggle();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(cubit.state, ThemeMode.dark);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'dark');
    cubit.close();
  });

  test('ThemeCubit setSystem persists system', () async {
    SharedPreferences.setMockInitialValues({'theme_mode': 'dark'});
    final cubit = ThemeCubit();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(cubit.state, ThemeMode.dark);

    cubit.setSystem();
    await Future.delayed(const Duration(milliseconds: 50));
    expect(cubit.state, ThemeMode.system);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme_mode'), 'system');
    cubit.close();
  });
}

