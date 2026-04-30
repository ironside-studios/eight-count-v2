import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/features/custom/models/custom_config.dart';
import 'package:eight_count/features/custom/services/custom_workout_adapter.dart';

/// Bug 4 protection: TOTAL math for Custom workouts must equal
///   (rounds × workSeconds) + ((rounds - 1) × restSeconds)
/// — pre-countdown EXCLUDED from total. Final round's bell_end fires
/// at TOTAL == 0 (1s-early shift acceptable per Boxing option-b).
///
/// Tests the values via [CustomConfig.totalWorkoutSeconds] AND verify
/// the engine-facing [WorkoutConfig] adapter produces durations the
/// engine multiplies into the same total.
void main() {
  group('TOTAL math — 4 spec configurations', () {
    test('Min bounds: 1 round × 10s work × 5s rest → 10s total', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test Min',
        rounds: 1,
        workSeconds: 10,
        restSeconds: 5,
      );
      // Math: (1 × 10) + ((1 - 1) × 5) = 10. No rest periods on a
      // single-round workout.
      expect(c.totalWorkoutSeconds, 10);
      // Engine path: adapted config must produce the same total when
      // computed engine-side as N×work + (N-1)×rest.
      final wc = customConfigToWorkoutConfig(c);
      final engineTotal = wc.workDuration.inSeconds * wc.totalRounds +
          wc.restDuration.inSeconds * (wc.totalRounds - 1);
      expect(engineTotal, 10);
    });

    test('Default: 5 rounds × 90s × 30s → 570s = 9:30', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test Std',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      // Math: (5 × 90) + (4 × 30) = 450 + 120 = 570.
      expect(c.totalWorkoutSeconds, 570);
      final wc = customConfigToWorkoutConfig(c);
      final engineTotal = wc.workDuration.inSeconds * wc.totalRounds +
          wc.restDuration.inSeconds * (wc.totalRounds - 1);
      expect(engineTotal, 570);
    });

    test('Boxing-match: 12 rounds × 180s × 60s → 2820s = 47:00 '
        '(must match WorkoutConfig.boxing exactly)', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test Boxing-Match',
        rounds: 12,
        workSeconds: 180,
        restSeconds: 60,
      );
      // Math: (12 × 180) + (11 × 60) = 2160 + 660 = 2820. Identical
      // to Boxing's TOTAL — sanity check that Custom + Boxing produce
      // the same number when fed the same inputs.
      expect(c.totalWorkoutSeconds, 2820);
      final wc = customConfigToWorkoutConfig(c);
      final engineTotal = wc.workDuration.inSeconds * wc.totalRounds +
          wc.restDuration.inSeconds * (wc.totalRounds - 1);
      expect(engineTotal, 2820);
    });

    test('Max bounds: 30 rounds × 600s × 300s → 26700s = 7h25m', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test Max',
        rounds: 30,
        workSeconds: 600,
        restSeconds: 300,
      );
      // Math: (30 × 600) + (29 × 300) = 18000 + 8700 = 26700.
      expect(c.totalWorkoutSeconds, 26700);
      final wc = customConfigToWorkoutConfig(c);
      final engineTotal = wc.workDuration.inSeconds * wc.totalRounds +
          wc.restDuration.inSeconds * (wc.totalRounds - 1);
      expect(engineTotal, 26700);
    });
  });

  group('TOTAL math — Bug 4 invariant', () {
    test('preCountdown is NOT included in totalWorkoutSeconds', () {
      // CustomConfig.totalWorkoutSeconds excludes preCountdown by
      // contract. The engine layer's _remainingTotalSeconds for
      // non-Smoker WorkoutConfig (in timer_screen.dart) computes the
      // same N×work + (N-1)×rest, with display-formula preCountdown
      // subtraction matching the underlying math.
      final c = CustomConfig.empty(0).copyWith(
        name: 'PC-Exclusion',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      // 570 = (5 × 90) + (4 × 30). 45 (preCountdown) NOT added.
      expect(c.totalWorkoutSeconds, 570);
      expect(c.totalWorkoutSeconds, isNot(equals(615)),
          reason: 'preCountdown (45s) must not bleed into total');
    });

    test('Single-round workout has no rest factor in total', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Single-Round',
        rounds: 1,
        workSeconds: 60,
        restSeconds: 30,
      );
      // (1 × 60) + (0 × 30) = 60. The (rounds - 1) clamp prevents
      // a phantom rest period at the end of a 1-round workout.
      expect(c.totalWorkoutSeconds, 60);
    });
  });
}
