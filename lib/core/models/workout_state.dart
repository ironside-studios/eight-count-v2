import 'workout_phase.dart';

/// Immutable UI-facing snapshot of the workout engine. Built fresh from the
/// engine's internal state on every `engine.state` read — never stored.
class WorkoutState {
  const WorkoutState({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.phaseRemaining,
    required this.phaseDuration,
    required this.isPaused,
  });

  final WorkoutPhase phase;

  /// 1-indexed round number. 0 during preCountdown; equals [totalRounds] at complete.
  final int currentRound;

  final int totalRounds;

  /// Time left in the current phase. Derived from DateTime math in the engine.
  final Duration phaseRemaining;

  /// Full duration of the current phase — used for progress fraction.
  final Duration phaseDuration;

  final bool isPaused;

  bool get isLastRound => currentRound == totalRounds;

  /// 0.0 at phase entry, 1.0 at phase end. Guarded against zero-duration phases
  /// (e.g., the complete phase) which would otherwise divide by zero.
  double get progress {
    final denom = phaseDuration.inMilliseconds;
    if (denom <= 0) return 1.0;
    return 1.0 -
        (phaseRemaining.inMilliseconds / denom).clamp(0.0, 1.0);
  }
}
