import 'workout_block_type.dart';
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
    this.currentBlockIndex,
    this.blockType,
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

  /// 1-indexed CONTENT-block number (1..4 for the V2 Smoker preset),
  /// or null for non-Smoker presets. During a transition this points at
  /// the most-recently-completed content block.
  final int? currentBlockIndex;

  /// The type of the current block (boxing / tabata / transition) for
  /// Smoker workouts; null for single-block presets (Boxing, Custom).
  final WorkoutBlockType? blockType;

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
