import 'package:flutter/material.dart';

class AppThemes {
  static final Color lightPrimary = Color(0xFFF8F9FA); // Lightest gray
  static final Color lightSecondary = Color(0xFFCED4DA); // Soft gray
  static final Color lightBackground =
      Color(0xFFE9ECEF); // Light gray background
  static final Color lightSurface = Color(0xFFDEE2E6); // Slightly darker gray
  static final Color lightTextPrimary =
      Color(0xFF212529); // Dark text for light theme
  static final Color lightTextSecondary =
      Color(0xFF495057); // Subtle dark gray text

  static final Color darkPrimary =
      Color(0xFF212529); // Deep gray for dark theme
  static final Color darkSecondary =
      Color(0xFF343A40); // Dark gray for elements
  static final Color darkBackground =
      Color(0xFF212529); // Background for dark theme
  static final Color darkSurface = Color(0xFF343A40); // Surface for dark mode
  static final Color darkTextPrimary =
      Color(0xFFF8F9FA); // Light text for dark theme
  static final Color darkTextSecondary =
      Color(0xFFADB5BD); // Softer light gray text

  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,
    colorScheme: ColorScheme.light(
      primary: lightPrimary,
      secondary: lightSecondary,
      surface: lightSurface,
    ),
    cardColor: lightSurface,
    textTheme: TextTheme(
      titleMedium: TextStyle(color: lightTextPrimary),
      bodyMedium: TextStyle(color: lightTextSecondary),
    ),
    appBarTheme: AppBarTheme(
      color: lightPrimary,
      iconTheme: IconThemeData(color: lightTextPrimary),
      titleTextStyle: TextStyle(
          color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    iconTheme: IconThemeData(color: lightTextPrimary),
    buttonTheme: ButtonThemeData(buttonColor: lightSecondary),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: lightBackground,
      modalBackgroundColor: lightSurface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: lightTextPrimary,
        backgroundColor: darkPrimary,
        textStyle: TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: darkPrimary,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: ColorScheme.dark(
      primary: darkPrimary,
      secondary: darkSecondary,
      surface: darkSurface,
    ),
    cardColor: darkSurface,
    textTheme: TextTheme(
      titleMedium: TextStyle(color: darkTextPrimary),
      bodyMedium: TextStyle(color: darkTextSecondary),
    ),
    appBarTheme: AppBarTheme(
      color: darkPrimary,
      iconTheme: IconThemeData(color: darkTextPrimary),
      titleTextStyle: TextStyle(
          color: darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    iconTheme: IconThemeData(color: darkTextPrimary),
    buttonTheme: ButtonThemeData(buttonColor: darkSecondary),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkSecondary,
      modalBackgroundColor: darkSurface,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: darkTextPrimary,
        backgroundColor: darkPrimary,
        textStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    ),
  );
}
