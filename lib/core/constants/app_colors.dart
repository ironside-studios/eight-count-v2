import 'package:flutter/material.dart';

/// 8 Count V2 Design System — Color Tokens
/// Locked 4/20/26. Do not add colors without design review.
class AppColors {
  AppColors._();

  // Base surfaces
  // Locked 4/22/26 — premium polish pass
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);

  // Brand accent
  // Locked 4/22/26 — premium polish pass
  static const Color gold = Color(0xFFE5B842);

  // Tuned gold palette for letterpress effect
  // goldTuned is the base — slightly warmer, less saturated than flat #D4A017
  static const Color goldTuned = Color(0xFFCDA349);
  static const Color goldHighlight = Color(0xFFE8C352);
  static const Color goldShadow = Color(0xFF8B6508);

  // Card surface — one step off pure black for subtle depth
  static const Color cardSurface = Color(0xFF141414);
  static const Color cardSurfacePressed = Color(0xFF1C1C1C);

  // Secondary
  static const Color greyMuted = Color(0xFF8A8A8A);

  // Timer ring states (used in later step when ring is built)
  static const Color ringGreen = Color(0xFF22C55E);
  static const Color ringYellow = Color(0xFFEAB308);
  static const Color ringRed = Color(0xFFEF4444);
}
