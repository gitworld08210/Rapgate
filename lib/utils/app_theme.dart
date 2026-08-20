import 'package:flutter/material.dart';
/// Typography.
///
/// This previously used `google_fonts`, which fetches font binaries over HTTP
/// on first launch and blocks text from rendering until the download finishes.
/// That was the single largest cold-start cost in the app, so it was removed.
///
/// [AppFonts.family] of `null` means "use the platform default" (Roboto on
/// Android, San Francisco on iOS) — zero network, zero delay.
///
/// To restore the Plus Jakarta Sans look without the startup penalty, bundle
/// the font instead of downloading it:
///   1. Put the .ttf files in `assets/fonts/`
///   2. Declare them in `pubspec.yaml` under `flutter: fonts:`
///        fonts:
///          - family: PlusJakartaSans
///            fonts:
///              - asset: assets/fonts/PlusJakartaSans-Regular.ttf
///              - asset: assets/fonts/PlusJakartaSans-Bold.ttf
///                weight: 700
///   3. Set `AppFonts.family = 'PlusJakartaSans'` below
class AppFonts {
  /// `null` = platform default font. Set to a bundled family name to override.
  static const String? family = null;
}

/// Builds a [TextStyle] using the app font family.
///
/// Drop-in replacement for the old `GoogleFonts.plusJakartaSans(...)` calls,
/// so the call sites below read the same but resolve instantly and offline.
TextStyle _font({
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
  double? letterSpacing,
  double? height,
  FontStyle? fontStyle,
  TextDecoration? decoration,
}) {
  return TextStyle(
    fontFamily: AppFonts.family,
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
    fontStyle: fontStyle,
    decoration: decoration,
  );
}

/// Design tokens extracted from the reference UI concept:
/// fresh lime-green + white + near-black, very rounded soft cards.
class AppColors {
  // ---- Brand: lime / chartreuse family ----
  static const lime = Color(0xFFC4E86B); // primary lime
  static const limeBright = Color(0xFFB5E048); // active/selected
  static const limeDeep = Color(0xFFA3D93F); // pressed
  static const limeSoft = Color(0xFFE8F5D0); // tinted fill
  static const limeWash = Color(0xFFF4FAE8); // page wash / very light
  static const green = Color(0xFF8BC34A); // supporting green

  // ---- Neutrals ----
  static const ink = Color(0xFF111111); // near-black (buttons, headings)
  static const inkSoft = Color(0xFF2A2A2A);
  static const grey900 = Color(0xFF1C1C1E);
  static const grey700 = Color(0xFF3A3A3C);
  static const grey500 = Color(0xFF8E8E93); // secondary text
  static const grey300 = Color(0xFFC7C7CC);
  static const grey200 = Color(0xFFE5E5EA); // borders / track
  static const grey100 = Color(0xFFF2F2F7); // subtle fill
  static const white = Color(0xFFFFFFFF);

  // ---- Macro accents (from the reference macro chips) ----
  static const carbs = Color(0xFF34C759); // green
  static const protein = Color(0xFF2196F3); // blue
  static const fat = Color(0xFFFFC107); // yellow
  static const burned = Color(0xFFFF9500); // orange
  static const heart = Color(0xFFFF3B30); // red

  // ---- Pastel tiles ----
  static const pastelOrange = Color(0xFFFFF4E0);
  static const pastelBlue = Color(0xFFE8F0FE);
  static const pastelGreen = Color(0xFFF0F7E4);
  static const pastelPink = Color(0xFFFFEDEB);
  static const pastelPurple = Color(0xFFF1EDFF);

  // ---- Semantic ----
  static const success = Color(0xFF34C759);
  static const warning = Color(0xFFFF9500);
  static const danger = Color(0xFFFF3B30);
  static const water = Color(0xFF32ADE6);

  // ---- Dark mode surfaces ----
  static const darkBg = Color(0xFF0F1110);
  static const darkSurface = Color(0xFF1A1D1B);
  static const darkCard = Color(0xFF222623);
  static const darkBorder = Color(0xFF2E332F);
}

/// Spacing / radius / shadow scale
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Standard horizontal page padding
  static const page = EdgeInsets.symmetric(horizontal: 20);
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const xl = 24.0;
  static const xxl = 28.0;
  static const pill = 999.0;

  static BorderRadius get card => BorderRadius.circular(xl);
  static BorderRadius get cardLg => BorderRadius.circular(xxl);
  static BorderRadius get chip => BorderRadius.circular(pill);
}

class AppShadows {
  /// Soft diffuse shadow used on nearly every card in the reference
  static List<BoxShadow> get soft => [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get medium => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  /// For the floating bottom nav / FAB
  static List<BoxShadow> get floating => [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get limeGlow => [
        BoxShadow(
          color: AppColors.limeDeep.withOpacity(0.4),
          blurRadius: 20,
          offset: const Offset(0, 6),
        ),
      ];
}

class AppTheme {
  // Legacy aliases so existing screens keep compiling
  static const Color primaryColor = AppColors.limeBright;
  static const Color secondaryColor = AppColors.burned;
  static const Color accentColor = AppColors.protein;
  static const Color dangerColor = AppColors.danger;
  static const Color successColor = AppColors.success;
  static const Color warningColor = AppColors.warning;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.white,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink, // black CTAs are the primary action
        onPrimary: AppColors.white,
        secondary: AppColors.limeBright,
        onSecondary: AppColors.ink,
        surface: AppColors.white,
        onSurface: AppColors.ink,
        surfaceContainerHighest: AppColors.grey100,
        error: AppColors.danger,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.ink,
        titleTextStyle: _font(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.white,
          disabledBackgroundColor: AppColors.grey200,
          disabledForegroundColor: AppColors.grey500,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
          textStyle: _font(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.grey200, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
          textStyle: _font(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: _font(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.grey100,
        hintStyle: _font(
          color: AppColors.grey500,
          fontSize: 15,
        ),
        labelStyle: _font(
          color: AppColors.grey500,
          fontSize: 15,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.grey100,
        selectedColor: AppColors.limeBright,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
        labelStyle: _font(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.grey200,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: _font(
          color: AppColors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.grey200,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.limeSoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return _font(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.grey500,
          );
        }),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.limeBright,
        onPrimary: AppColors.ink,
        secondary: AppColors.lime,
        onSecondary: AppColors.ink,
        surface: AppColors.darkSurface,
        onSurface: AppColors.white,
        error: AppColors.danger,
      ),
      textTheme: _textTheme(base.textTheme, AppColors.white),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        foregroundColor: AppColors.white,
        titleTextStyle: _font(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.card),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.limeBright,
          foregroundColor: AppColors.ink,
          disabledBackgroundColor: AppColors.darkBorder,
          disabledForegroundColor: AppColors.grey500,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
          textStyle: _font(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkCard,
        hintStyle: _font(color: AppColors.grey500),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.limeBright, width: 1.5),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base, Color color) {
    return base.copyWith(
      displayLarge: _font(
        fontSize: 40,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.1,
        color: color,
      ),
      displayMedium: _font(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.15,
        color: color,
      ),
      headlineLarge: _font(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: color,
      ),
      headlineMedium: _font(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        color: color,
      ),
      titleLarge: _font(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      ),
      titleMedium: _font(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      titleSmall: _font(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
      bodyLarge: _font(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      ),
      bodyMedium: _font(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
        color: color,
      ),
      bodySmall: _font(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.grey500,
      ),
      labelLarge: _font(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      ),
      labelMedium: _font(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.grey500,
      ),
      labelSmall: _font(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.grey500,
      ),
    );
  }
}
