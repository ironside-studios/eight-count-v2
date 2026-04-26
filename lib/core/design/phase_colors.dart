import 'package:flutter/material.dart';

import '../models/workout_phase.dart';

/// Phase-coded accent colors for the timer screen ring + phase label.
/// Pre-countdown uses gold to signal "get ready". Work uses green for "go".
/// Rest uses red for "stop / recover". OLED-calibrated.
const Color phaseColorPreCountdown = Color(0xFFF5C518); // gold (brand accent)
const Color phaseColorWork = Color(0xFF16A34A); // green-600
const Color phaseColorRest = Color(0xFFDC2626); // red-600

/// Accent color for the given workout phase. [WorkoutPhase.complete] now
/// renders red (same as rest) because the timer screen holds on the ":00"
/// frame for ~1s after the final bell before routing to /complete — that
/// frame should read as "workout finished / stop", not "get ready".
Color colorForPhase(WorkoutPhase phase) {
  switch (phase) {
    case WorkoutPhase.preCountdown:
      return phaseColorPreCountdown;
    case WorkoutPhase.work:
      return phaseColorWork;
    case WorkoutPhase.rest:
      return phaseColorRest;
    case WorkoutPhase.complete:
      return phaseColorRest;
  }
}

/// Color for the big digit and the phase label text.
///
/// All phases use white for the digit + phase label (locked 4/22/26 — was
/// gold for preCountdown in 3.2.1.2, changed for cross-phase consistency).
/// The ring color still varies by phase via [colorForPhase] — that's the
/// single carrier of phase state. Kept as a function (not a constant) so
/// Smoker (Step 6) can override per-block if its design calls for it.
Color digitColorForPhase(WorkoutPhase phase) {
  switch (phase) {
    case WorkoutPhase.preCountdown:
    case WorkoutPhase.work:
    case WorkoutPhase.rest:
    case WorkoutPhase.complete:
      return Colors.white;
  }
}
