import 'workout_block.dart';
import 'workout_block_type.dart';

/// Multi-block workout config consumed by [WorkoutEngine] alongside
/// (and distinct from) [WorkoutConfig]. The engine accepts either as
/// `Object config` and dispatches on `is` checks.
///
/// Sibling — NOT subclass — of WorkoutConfig: the two presets have
/// different shapes (single-block vs. block sequence), so unifying
/// them under one type would force every Boxing call site to know
/// about blocks it doesn't have.
class SmokerConfig {
  const SmokerConfig({
    required this.presetId,
    required this.preCountdown,
    required this.blocks,
  });

  final String presetId;
  final Duration preCountdown;
  final List<WorkoutBlock> blocks;

  /// Sum of rounds across all CONTENT blocks (transitions excluded).
  /// V2 standard Smoker = 6 + 8 + 6 + 8 = 28.
  int get totalRounds => blocks
      .where((b) => b.blockType != WorkoutBlockType.transition)
      .fold<int>(0, (sum, b) => sum + b.totalRounds);

  /// V2.0 Smoker preset (locked).
  ///
  /// Block 1: Boxing  6×180/60
  ///   ↓ 60s transition
  /// Block 2: Tabata  8×20/10
  ///   ↓ 60s transition
  /// Block 3: Boxing  6×180/60
  ///   ↓ 60s transition
  /// Block 4: Tabata  8×20/10
  factory SmokerConfig.standard() => SmokerConfig(
        presetId: 'smoker',
        preCountdown: const Duration(seconds: 45),
        blocks: [
          WorkoutBlock.boxing(
            rounds: 6,
            work: const Duration(seconds: 180),
            rest: const Duration(seconds: 60),
          ),
          WorkoutBlock.transition(),
          WorkoutBlock.tabata(
            rounds: 8,
            work: const Duration(seconds: 20),
            rest: const Duration(seconds: 10),
          ),
          WorkoutBlock.transition(),
          WorkoutBlock.boxing(
            rounds: 6,
            work: const Duration(seconds: 180),
            rest: const Duration(seconds: 60),
          ),
          WorkoutBlock.transition(),
          WorkoutBlock.tabata(
            rounds: 8,
            work: const Duration(seconds: 20),
            rest: const Duration(seconds: 10),
          ),
        ],
      );
}
