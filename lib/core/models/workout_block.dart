import 'workout_block_type.dart';

/// One segment of a multi-block workout (Smoker preset).
///
/// Content blocks (boxing, tabata) carry [totalRounds] periods of
/// work + rest. Transition blocks are modeled as a single period:
/// [totalRounds] = 1, [workDuration] = [Duration.zero], [restDuration]
/// = the transition duration. The engine skips the work phase of a
/// transition block and runs only the rest period.
class WorkoutBlock {
  const WorkoutBlock({
    required this.blockType,
    required this.totalRounds,
    required this.workDuration,
    required this.restDuration,
  });

  final WorkoutBlockType blockType;
  final int totalRounds;
  final Duration workDuration;
  final Duration restDuration;

  factory WorkoutBlock.boxing({
    required int rounds,
    required Duration work,
    required Duration rest,
  }) =>
      WorkoutBlock(
        blockType: WorkoutBlockType.boxing,
        totalRounds: rounds,
        workDuration: work,
        restDuration: rest,
      );

  factory WorkoutBlock.tabata({
    required int rounds,
    required Duration work,
    required Duration rest,
  }) =>
      WorkoutBlock(
        blockType: WorkoutBlockType.tabata,
        totalRounds: rounds,
        workDuration: work,
        restDuration: rest,
      );

  factory WorkoutBlock.transition({
    Duration duration = const Duration(seconds: 60),
  }) =>
      WorkoutBlock(
        blockType: WorkoutBlockType.transition,
        totalRounds: 1,
        workDuration: Duration.zero,
        restDuration: duration,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WorkoutBlock &&
        other.blockType == blockType &&
        other.totalRounds == totalRounds &&
        other.workDuration == workDuration &&
        other.restDuration == restDuration;
  }

  @override
  int get hashCode =>
      Object.hash(blockType, totalRounds, workDuration, restDuration);
}
