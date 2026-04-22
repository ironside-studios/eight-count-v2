import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// 8 Count V2 — App Theme
/// Dark, premium, handcrafted. No Material defaults for branded surfaces.
class AppTheme {
  AppTheme._();

  /// Edge-to-edge system bars: transparent status bar with light icons,
  /// pure-black nav bar with light icons. Call from main() before runApp().
  static const SystemUiOverlayStyle systemOverlay = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.black,
    systemNavigationBarIconBrightness: Brightness.light,
    systemNavigationBarContrastEnforced: false,
  );

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.black,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.black,
        primary: AppColors.gold,
        secondary: AppColors.gold,
        onSurface: AppColors.white,
        onPrimary: AppColors.black,
      ),
      textTheme: GoogleFonts.interTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme,
      ).apply(
        bodyColor: AppColors.white,
        displayColor: AppColors.white,
      ),
    );
  }

  /// Display font for large timer digits, headlines, primary CTAs.
  static TextStyle displayFont({
    required double fontSize,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
  }) {
    return GoogleFonts.bebasNeue(
      fontSize: fontSize,
      color: color ?? AppColors.white,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: letterSpacing ?? 1.0,
    );
  }

  /// Tuned gold with letterpress effect — embossed/stamped look for branded type.
  /// Uses layered shadows to create the illusion of engraving on a dark surface.
  /// Pass this as a TextStyle to Bebas Neue headlines for the premium brand feel.
  static TextStyle goldLetterpress({
    required double fontSize,
    double? letterSpacing,
    FontWeight? fontWeight,
  }) {
    return GoogleFonts.bebasNeue(
      fontSize: fontSize,
      color: AppColors.goldTuned,
      fontWeight: fontWeight ?? FontWeight.w400,
      letterSpacing: letterSpacing ?? 2.0,
      shadows: const [
        // Inner top highlight (lighter gold) — simulates light catching the engraving's top edge
        Shadow(
          color: Color(0xFFE8C352),
          offset: Offset(0, -0.5),
          blurRadius: 0,
        ),
        // Bottom shadow (deep amber) — simulates depth of the engraving's lower edge
        Shadow(
          color: Color(0xFF8B6508),
          offset: Offset(0, 1),
          blurRadius: 1,
        ),
      ],
    );
  }
}
