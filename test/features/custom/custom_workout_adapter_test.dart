import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/features/custom/models/custom_config.dart';
import 'package:eight_count/features/custom/services/custom_workout_adapter.dart';

/// Adapter is a thin delegating wrapper around [WorkoutConfig.custom],
/// but the contract is locked: rounds/work/rest must pass through
/// verbatim, presetId must be 'custom', preCountdown stays at 45s.
void main() {
  group('customConfigToWorkoutConfig — value passthrough', () {
    test('rounds passed through verbatim', () {
      for (final rounds in [1, 5, 12, 30]) {
        final c = CustomConfig.empty(0).copyWith(
          name: 'Test',
          rounds: rounds,
          workSeconds: 60,
          restSeconds: 30,
        );
        expect(customConfigToWorkoutConfig(c).totalRounds, rounds);
      }
    });

    test('workSeconds passed through verbatim', () {
      for (final work in [10, 60, 90, 180, 600]) {
        final c = CustomConfig.empty(0).copyWith(
          name: 'Test',
          rounds: 5,
          workSeconds: work,
          restSeconds: 30,
        );
        expect(
          customConfigToWorkoutConfig(c).workDuration.inSeconds,
          work,
        );
      }
    });

    test('restSeconds passed through verbatim', () {
      for (final rest in [5, 20, 60, 120, 300]) {
        final c = CustomConfig.empty(0).copyWith(
          name: 'Test',
          rounds: 5,
          workSeconds: 60,
          restSeconds: rest,
        );
        expect(
          customConfigToWorkoutConfig(c).restDuration.inSeconds,
          rest,
        );
      }
    });
  });

  group('customConfigToWorkoutConfig — locked contract', () {
    test('presetId is always "custom"', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test',
        rounds: 5,
        workSeconds: 60,
        restSeconds: 30,
      );
      expect(customConfigToWorkoutConfig(c).presetId, 'custom');
    });

    test('preCountdown is always 45s (locked app warmup)', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Test',
        rounds: 5,
        workSeconds: 60,
        restSeconds: 30,
      );
      expect(
        customConfigToWorkoutConfig(c).preCountdown.inSeconds,
        45,
      );
    });
  });

  group('customConfigToWorkoutConfig — bound configurations', () {
    test('min bounds: 1 round × 10s × 5s', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Min',
        rounds: 1,
        workSeconds: 10,
        restSeconds: 5,
      );
      final wc = customConfigToWorkoutConfig(c);
      expect(wc.totalRounds, 1);
      expect(wc.workDuration.inSeconds, 10);
      expect(wc.restDuration.inSeconds, 5);
      expect(wc.presetId, 'custom');
      expect(wc.preCountdown.inSeconds, 45);
    });

    test('max bounds: 30 rounds × 600s × 300s', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Max',
        rounds: 30,
        workSeconds: 600,
        restSeconds: 300,
      );
      final wc = customConfigToWorkoutConfig(c);
      expect(wc.totalRounds, 30);
      expect(wc.workDuration.inSeconds, 600);
      expect(wc.restDuration.inSeconds, 300);
    });

    test('boxing-match config (12 × 180 × 60) produces identical '
        'shape to WorkoutConfig.boxing modulo presetId', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Boxing-Match',
        rounds: 12,
        workSeconds: 180,
        restSeconds: 60,
      );
      final adapted = customConfigToWorkoutConfig(c);
      final boxing = WorkoutConfig.boxing();

      expect(adapted.totalRounds, boxing.totalRounds);
      expect(adapted.workDuration, boxing.workDuration);
      expect(adapted.restDuration, boxing.restDuration);
      expect(adapted.preCountdown, boxing.preCountdown);
      // presetId differs: boxing → 'boxing', adapted → 'custom'.
      expect(adapted.presetId, 'custom');
      expect(boxing.presetId, 'boxing');
    });
  });

  group('customConfigToWorkoutConfig — unsaved input', () {
    test('empty config still adapts (defaults flow through)', () {
      final empty = CustomConfig.empty(2);
      final wc = customConfigToWorkoutConfig(empty);
      // Defaults from CustomConfig.empty: rounds=5, work=90, rest=30.
      expect(wc.totalRounds, 5);
      expect(wc.workDuration.inSeconds, 90);
      expect(wc.restDuration.inSeconds, 30);
    });
  });

  group('customConfigToWorkoutConfig — purity', () {
    test('called twice with the same input produces equal configs', () {
      final c = CustomConfig.empty(0).copyWith(
        name: 'Determinism',
        rounds: 8,
        workSeconds: 120,
        restSeconds: 45,
      );
      final a = customConfigToWorkoutConfig(c);
      final b = customConfigToWorkoutConfig(c);
      expect(a, equals(b));
    });
  });
}
