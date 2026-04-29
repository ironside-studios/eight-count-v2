import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// One falling stream's mutable state. Mutated in place each frame by
/// [MatrixRainPainter]'s host widget; the painter never allocates new
/// instances during paint.
class RainStream {
  RainStream({
    required this.xPx,
    required this.headYPx,
    required this.speedPxS,
    required this.length,
    this.fadeOutMs = 0,
  });

  /// Logical x position of the column (random per spawn).
  double xPx;

  /// Current y position of the head (bottom-most) character.
  double headYPx;

  /// Falling speed in logical pixels per second.
  double speedPxS;

  /// Number of visible characters in the trail (head + above).
  int length;

  /// Counts up from 0 to 400ms when the stream is fading out before
  /// respawn. Zero while the stream is active and not yet at its end.
  double fadeOutMs;

  bool get isFading => fadeOutMs > 0;
}

/// Paints the falling-character matrix-rain effect.
///
/// Single [CustomPainter] per [CustomPaint] widget. Rebuilds via the
/// `repaint` listenable on the host's `CustomPaint` — this painter never
/// does its own state mutation. Stream state is owned by the host
/// widget's State and passed in.
class MatrixRainPainter extends CustomPainter {
  MatrixRainPainter({
    required Listenable repaint,
    required this.streams,
    required this.bleedThroughText,
    required this.bleedThroughEnabled,
  }) : super(repaint: repaint);

  final List<RainStream> streams;

  /// Pre-laid TextPainter for the static "8COUNT" bleed-through layer
  /// plus its bounding rect (computed by the host widget on layout
  /// changes, NOT every frame).
  final ({TextPainter painter, Rect rect})? bleedThroughText;

  final bool bleedThroughEnabled;

  /// Stream characters are drawn from this cycle. Each row down a stream
  /// picks the next character so the stream visually reads as "8COUNT"
  /// repeating.
  static const String _charCycle = '8COUNT';

  /// Vertical line height between characters in a stream. Locked here so
  /// trail spacing is consistent regardless of font metrics.
  static const double _lineHeight = 22.0;

  /// Font size of stream characters. Locked.
  static const double _charFontSize = 18.0;

  // --- Color tokens for the trail gradient ---
  static const Color _headColor = Color(0xFFFFD700); // bright gold
  static const Color _trailHi = Color(0xFFD4A017); // warm gold
  static const Color _trailMid = Color(0xFF7A5C0E); // dark amber
  static const Color _trailLo = Color(0xFF1A1408); // near-black

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Bleed-through "8COUNT" first so streams overlay it.
    if (bleedThroughEnabled && bleedThroughText != null) {
      bleedThroughText!.painter.paint(
        canvas,
        bleedThroughText!.rect.topLeft,
      );
    }

    // 2) Streams.
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (final s in streams) {
      // Per-stream fade scalar: 1.0 while active, lerp 1→0 across the
      // 400ms fade-out window.
      final double streamAlpha =
          s.isFading ? (1.0 - (s.fadeOutMs / 400.0)).clamp(0.0, 1.0) : 1.0;
      if (streamAlpha <= 0) continue;

      for (int i = 0; i < s.length; i++) {
        // Character index 0 = head (bottom-most), increasing = up the trail.
        final double charY = s.headYPx - i * _lineHeight;
        if (charY < -_lineHeight || charY > size.height) continue;

        final double trailFraction = s.length <= 1 ? 0 : i / (s.length - 1);
        final double opacity = (1.0 - 0.85 * trailFraction) * streamAlpha;

        Color color;
        if (i == 0) {
          color = _headColor;
        } else {
          // Two-segment lerp: head-1 → mid at 0.5 → top.
          if (trailFraction < 0.5) {
            color = Color.lerp(_trailHi, _trailMid, trailFraction * 2)!;
          } else {
            color =
                Color.lerp(_trailMid, _trailLo, (trailFraction - 0.5) * 2)!;
          }
        }

        // Bleed-through brightening: if the char center is over the
        // bleed-through text rect, lerp toward white by 0.3.
        final double charCenterY = charY + _lineHeight / 2;
        final double charCenterX = s.xPx + _charFontSize / 2;
        if (bleedThroughEnabled &&
            bleedThroughText != null &&
            bleedThroughText!.rect
                .contains(Offset(charCenterX, charCenterY))) {
          color = Color.lerp(color, const Color(0xFFFFFFFF), 0.3)!;
        }

        // For the head, draw a soft glow underneath then the crisp char.
        final char = _charCycle[(i) % _charCycle.length];

        if (i == 0) {
          // Glow pass: same char, blurred, slightly larger via shadow.
          final glowTp = TextPainter(
            text: TextSpan(
              text: char,
              style: GoogleFonts.bebasNeue(
                fontSize: _charFontSize,
                color: color.withValues(alpha: opacity * 0.85),
                shadows: <Shadow>[
                  Shadow(
                    color: color.withValues(alpha: opacity * 0.7),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          glowTp.paint(canvas, Offset(s.xPx, charY));
        } else {
          tp.text = TextSpan(
            text: char,
            style: GoogleFonts.bebasNeue(
              fontSize: _charFontSize,
              color: color.withValues(alpha: opacity),
            ),
          );
          tp.layout();
          tp.paint(canvas, Offset(s.xPx, charY));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant MatrixRainPainter old) =>
      old.streams != streams ||
      old.bleedThroughText != bleedThroughText ||
      old.bleedThroughEnabled != bleedThroughEnabled;
}

/// Helper used by the host widget to spawn a stream with random
/// parameters within the locked ranges. Kept here so painter + spawn
/// logic share constants.
RainStream spawnStream({
  required math.Random rng,
  required double screenWidth,
  required double initialHeadY,
  bool randomInitialY = false,
  required double screenHeight,
}) {
  final double speed = 60 + rng.nextDouble() * 80; // 60-140 px/s
  final int length = 8 + rng.nextInt(7); // 8-14
  final double xPx = rng.nextDouble() * (screenWidth - 12);
  final double headY = randomInitialY
      ? rng.nextDouble() * screenHeight
      : initialHeadY;
  return RainStream(
    xPx: xPx,
    headYPx: headY,
    speedPxS: speed,
    length: length,
  );
}

/// Builds the static "8COUNT" bleed-through TextPainter and its bounding
/// rect for the given screen size. Called once on layout, not per frame.
({TextPainter painter, Rect rect}) buildBleedThrough({
  required double screenWidth,
  required double screenHeight,
}) {
  // Locked sizing per spec: screenWidth * 0.28 clamped 96-160.
  final double fontSize = (screenWidth * 0.28).clamp(96.0, 160.0);
  final tp = TextPainter(
    text: TextSpan(
      text: '8COUNT',
      style: GoogleFonts.bebasNeue(
        fontSize: fontSize,
        color: const Color(0xFFD4A017).withValues(alpha: 0.12),
        letterSpacing: 4,
        fontWeight: ui.FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
  )..layout(maxWidth: screenWidth);
  // Vertical position: ~25-30% from top.
  final double y = screenHeight * 0.275 - tp.height / 2;
  final double x = (screenWidth - tp.width) / 2;
  final rect = Rect.fromLTWH(x, y, tp.width, tp.height);
  return (painter: tp, rect: rect);
}
