import '../../../core/models/workout_config.dart';
import '../models/custom_config.dart';

/// Pure adapter from the user-facing [CustomConfig] (Custom slot
/// model) to the engine-facing [WorkoutConfig] (consumed by
/// TimerScreen via its `overrideConfig` parameter).
///
/// Custom workouts use the existing Boxing-style engine path with
/// no parallel scheduler — only the inputs differ. The factory
/// [WorkoutConfig.custom] already encodes:
///   - presetId 'custom' (engine routes by this for non-Boxing
///     wood_clack suppression on lead-time + Tabata identity rule
///     branches)
///   - 45s preCountdown (locked)
///   - work/rest durations + round count
///
/// Pure function: deterministic, no side effects, no I/O. Trivially
/// testable.
WorkoutConfig customConfigToWorkoutConfig(CustomConfig customConfig) {
  return WorkoutConfig.custom(
    rounds: customConfig.rounds,
    workSeconds: customConfig.workSeconds,
    restSeconds: customConfig.restSeconds,
    // preCountdownSeconds intentionally omitted — the factory
    // defaults to 45s per the locked app-wide warmup contract.
  );
}
