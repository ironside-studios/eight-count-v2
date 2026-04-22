/// Immutable, value-equality preset definition consumed by WorkoutEngine.
///
/// The engine derives all phase durations from this config; the UI selects
/// which config to run via a preset picker.
class WorkoutConfig {
  const WorkoutConfig({
    required this.presetId,
    required this.totalRounds,
    required this.workDuration,
    required this.restDuration,
    required this.preCountdown,
  });

  final String presetId;
  final int totalRounds;
  final Duration workDuration;
  final Duration restDuration;
  final Duration preCountdown;

  /// V2.0 Free-tier Boxing preset. Locked values — do not parameterize
  /// without coordinating with the audio cue schedule.
  factory WorkoutConfig.boxing() => const WorkoutConfig(
        presetId: 'boxing',
        totalRounds: 12,
        workDuration: Duration(seconds: 180),
        restDuration: Duration(seconds: 60),
        preCountdown: Duration(seconds: 45),
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutConfig &&
        other.presetId == presetId &&
        other.totalRounds == totalRounds &&
        other.workDuration == workDuration &&
        other.restDuration == restDuration &&
        other.preCountdown == preCountdown;
  }

  @override
  int get hashCode => Object.hash(
        presetId,
        totalRounds,
        workDuration,
        restDuration,
        preCountdown,
      );
}
