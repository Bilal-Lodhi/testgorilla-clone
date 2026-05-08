import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:test_gorilla/core/theme/theme_provider.dart';
import 'package:test_gorilla/core/theme/app_theme.dart';

void main() {
  testWidgets('ThemeProvider defaults to light mode', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final themeProvider = ThemeProvider();
    await themeProvider.init();

    expect(themeProvider.isDarkMode, false);
    expect(themeProvider.themeMode, ThemeMode.light);
  });

  testWidgets('ThemeProvider toggles between light and dark', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final themeProvider = ThemeProvider();
    await themeProvider.init();

    await themeProvider.toggleTheme();
    expect(themeProvider.isDarkMode, true);
    expect(themeProvider.themeMode, ThemeMode.dark);

    await themeProvider.toggleTheme();
    expect(themeProvider.isDarkMode, false);
    expect(themeProvider.themeMode, ThemeMode.light);
  });

  testWidgets('ThemeProvider persists dark mode preference', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final themeProvider = ThemeProvider();
    await themeProvider.init();
    await themeProvider.toggleTheme(); // switch to dark

    // Create a new provider instance that should read the persisted value
    final newProvider = ThemeProvider();
    await newProvider.init();

    expect(newProvider.isDarkMode, true);
    expect(newProvider.themeMode, ThemeMode.dark);
  });

  test('Light theme has expected structure', () {
    final lightTheme = AppTheme.lightTheme;
    expect(lightTheme.brightness, Brightness.light);
    expect(lightTheme.useMaterial3, true);
    expect(lightTheme.colorScheme.primary, isA<Color>());
  });

  test('Dark theme has expected structure', () {
    final darkTheme = AppTheme.darkTheme;
    expect(darkTheme.brightness, Brightness.dark);
    expect(darkTheme.useMaterial3, true);
    expect(darkTheme.colorScheme.primary, isA<Color>());
  });
}
