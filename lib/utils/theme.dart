import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Central place for Jipange's color palette and theme data.
///
/// Design notes:
/// - Neutral surfaces (background/surface/text) stay a calm, low-key gray
///   scale so content is easy to read for long stretches.
/// - `lightSecondary` and `darkPrimary` double as the app's single shared
///   "accent" color across both themes (this mirrors how the rest of the
///   codebase already uses them, e.g. `isDarkMode ? lightSecondary :
///   darkPrimary`), just repointed from flat grays to a livelier indigo so
///   buttons, selection states, and highlights actually pop instead of
///   blending into the background.
/// - Every TextTheme style is defined explicitly (rather than relying on
///   Flutter's automatic light/dark merge) so there's no ambiguity about
///   what color text renders in bottom sheets, dialogs, and menus - the two
///   places this previously bit us.
class AppThemes {
  // Light theme neutrals
  static const Color lightPrimary = Color(0xFFF8F9FA); // AppBar / top surface
  static const Color lightSecondary =
      Color(0xFF6672E5); // Shared accent (used in dark-mode contexts)
  static const Color lightBackground = Color(0xFFF4F5F7); // Scaffold bg
  static const Color lightSurface = Color(0xFFFFFFFF); // Cards / sheets
  static const Color lightTextPrimary = Color(0xFF1B1E23); // High-emphasis
  static const Color lightTextSecondary = Color(0xFF585F6B); // Muted text

  // Dark theme neutrals
  static const Color darkPrimary =
      Color(0xFF7C86F5); // Shared accent (used in light-mode contexts)
  static const Color darkSecondary = Color(0xFF2A2E36); // Subtle surfaces
  static const Color darkBackground = Color(0xFF15171C); // Scaffold bg
  static const Color darkSurface = Color(0xFF1E2128); // Cards / sheets
  static const Color darkTextPrimary = Color(0xFFF3F4F6); // High-emphasis
  static const Color darkTextSecondary = Color(0xFFAFB5C0); // Muted text

  // Convenience accessor: the shared accent color for the given brightness.
  static Color accentFor(bool isDarkMode) =>
      isDarkMode ? lightSecondary : darkPrimary;

  static TextTheme _textTheme(Color primary, Color secondary) {
    return TextTheme(
      displayLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: primary, fontWeight: FontWeight.bold),
      displaySmall: TextStyle(color: primary, fontWeight: FontWeight.bold),
      headlineLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: primary, fontWeight: FontWeight.bold),
      headlineSmall: TextStyle(color: primary, fontWeight: FontWeight.bold),
      titleLarge: TextStyle(color: primary, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(color: primary, fontWeight: FontWeight.w600),
      titleSmall: TextStyle(color: primary, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: primary),
      bodyMedium: TextStyle(color: secondary),
      bodySmall: TextStyle(color: secondary),
      labelLarge: TextStyle(color: primary, fontWeight: FontWeight.w600),
      labelMedium: TextStyle(color: secondary),
      labelSmall: TextStyle(color: secondary),
    );
  }

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: lightPrimary,
    scaffoldBackgroundColor: lightBackground,
    canvasColor: lightSurface,
    dividerColor: lightTextSecondary.withValues(alpha: 0.15),
    hintColor: lightTextSecondary.withValues(alpha: 0.7),
    colorScheme: ColorScheme.light(
      primary: darkPrimary, // the shared vibrant accent
      onPrimary: Colors.white,
      secondary: lightSecondary,
      onSecondary: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainerHighest: lightBackground,
      error: const Color(0xFFD64545),
      onError: Colors.white,
    ),
    cardColor: lightSurface,
    cardTheme: CardThemeData(
      color: lightSurface,
      elevation: 1,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: _textTheme(lightTextPrimary, lightTextSecondary),
    appBarTheme: AppBarTheme(
      backgroundColor: lightPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: lightTextPrimary),
      titleTextStyle: const TextStyle(
          color: lightTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: lightTextPrimary),
    buttonTheme: const ButtonThemeData(buttonColor: lightSecondary),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: lightSurface,
      modalBackgroundColor: lightSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: lightSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
          color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: const TextStyle(color: lightTextSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(color: lightTextPrimary),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(lightSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: lightSurface,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(color: lightTextPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: lightTextPrimary,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? darkPrimary : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? darkPrimary.withValues(alpha: 0.5)
              : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: lightBackground,
      selectedColor: darkPrimary,
      labelStyle: const TextStyle(color: lightTextPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(color: lightTextSecondary.withValues(alpha: 0.25)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: darkPrimary.withValues(alpha: 0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? darkPrimary
                : lightTextSecondary,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? darkPrimary
                : lightTextSecondary,
          )),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: darkPrimary,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: darkPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(color: lightTextSecondary.withValues(alpha: 0.7)),
      labelStyle: const TextStyle(color: lightTextSecondary),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: darkPrimary, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide:
            BorderSide(color: lightTextSecondary.withValues(alpha: 0.3)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: darkPrimary,
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: darkPrimary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: darkSurface,
    scaffoldBackgroundColor: darkBackground,
    canvasColor: darkSurface,
    dividerColor: darkTextSecondary.withValues(alpha: 0.15),
    hintColor: darkTextSecondary.withValues(alpha: 0.7),
    colorScheme: ColorScheme.dark(
      primary: lightSecondary, // the shared vibrant accent
      onPrimary: Colors.white,
      secondary: darkSecondary,
      onSecondary: darkTextPrimary,
      surface: darkSurface,
      onSurface: darkTextPrimary,
      surfaceContainerHighest: darkSecondary,
      error: const Color(0xFFEF6E6E),
      onError: Colors.black,
    ),
    cardColor: darkSurface,
    cardTheme: CardThemeData(
      color: darkSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    textTheme: _textTheme(darkTextPrimary, darkTextSecondary),
    appBarTheme: AppBarTheme(
      backgroundColor: darkBackground,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: const IconThemeData(color: darkTextPrimary),
      titleTextStyle: const TextStyle(
          color: darkTextPrimary, fontSize: 20, fontWeight: FontWeight.bold),
    ),
    iconTheme: const IconThemeData(color: darkTextPrimary),
    buttonTheme: const ButtonThemeData(buttonColor: darkSecondary),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: darkSurface,
      modalBackgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: const TextStyle(
          color: darkTextPrimary, fontSize: 18, fontWeight: FontWeight.bold),
      contentTextStyle: const TextStyle(color: darkTextSecondary),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dropdownMenuTheme: DropdownMenuThemeData(
      textStyle: const TextStyle(color: darkTextPrimary),
      menuStyle: MenuStyle(
        backgroundColor: const WidgetStatePropertyAll(darkSurface),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: darkSurface,
      surfaceTintColor: Colors.transparent,
      textStyle: const TextStyle(color: darkTextPrimary),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: darkSecondary,
      contentTextStyle: const TextStyle(color: darkTextPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? lightSecondary : null),
      trackColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected)
              ? lightSecondary.withValues(alpha: 0.5)
              : null),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: darkSecondary,
      selectedColor: lightSecondary,
      labelStyle: const TextStyle(color: darkTextPrimary),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      side: BorderSide(color: darkTextSecondary.withValues(alpha: 0.25)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: lightSecondary.withValues(alpha: 0.2),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? lightSecondary
                : darkTextSecondary,
          )),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? lightSecondary
                : darkTextSecondary,
          )),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: lightSecondary,
      foregroundColor: Colors.white,
    ),
    progressIndicatorTheme:
        const ProgressIndicatorThemeData(color: lightSecondary),
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      hintStyle: TextStyle(color: darkTextSecondary.withValues(alpha: 0.7)),
      labelStyle: const TextStyle(color: darkTextSecondary),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: lightSecondary, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide:
            BorderSide(color: darkTextSecondary.withValues(alpha: 0.3)),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white,
        backgroundColor: lightSecondary,
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: lightSecondary),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
