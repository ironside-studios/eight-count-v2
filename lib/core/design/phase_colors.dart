import 'package:flutter/material.dart';

import '../models/workout_phase.dart';

/// Phase-coded accent colors for the timer screen ring + phase label.
/// Pre-countdown uses gold to signal "get ready". Work uses green for "go".
/// Rest uses red for "stop / recover". OLED-calibrated.
const Color phaseColorPreCountdown = Color(0xFFF5C518); // gold (brand accent)
const Color phaseColorWork = Color(0xFF16A34A); // green-600
const Color phaseColorRest = Color(0xFFDC2626); // red-600

/// Accent color for the given workout phase. [WorkoutPhase.complete] falls
/// back to gold because the timer screen pops to the complete screen the
/// moment the phase transitions — this value should never actually paint.
Color colorForPhase(WorkoutPhase phase) {
  switch (phase) {
    case WorkoutPhase.preCountdown:
      return phaseColorPreCountdown;
    case WorkoutPhase.work:
      return phaseColorWork;
    case WorkoutPhase.rest:
      return phaseColorRest;
    case WorkoutPhase.complete:
      return phaseColorPreCountdown;
  }
}

/// Color for the big digit and the phase label text.
///
/// Pre-countdown uses gold — the whole screen reads as the "brand hype"
/// moment before the workout begins. Work and rest use white for maximum
/// OLED contrast and fast glance-reads; the ring (via [colorForPhase])
/// carries phase state on its own. [WorkoutPhase.complete] never renders
/// on this screen.
Color digitColorForPhase(WorkoutPhase phase) {
  switch (phase) {
    case WorkoutPhase.preCountdown:
      return phaseColorPreCountdown;
    case WorkoutPhase.work:
    case WorkoutPhase.rest:
    case WorkoutPhase.complete:
      return Colors.white;
  }
}
