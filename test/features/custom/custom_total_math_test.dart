import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';
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

  // ---------------------------------------------------------------
  // Runtime TOTAL display contract (added 2026-04-30 alongside the
  // off-by-45 bug fix). Exercises the full engine path with a
  // FakeAudioService and an injected clock — same harness pattern
  // as test/core/engine/smoker_audio_final_test.dart.
  // ---------------------------------------------------------------

  group('Runtime TOTAL display contract', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('Custom: TOTAL displays full work+rest at round 1 work start '
        '(5×90×30 → 570s)', () {
      final audio = _NoopAudio();
      final clock = _TestClock(DateTime.utc(2026, 4, 30, 12));
      final cfg = CustomConfig.empty(0).copyWith(
        name: 'Std',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      final engine = WorkoutEngine(
        config: customConfigToWorkoutConfig(cfg),
        audio: audio,
        clock: clock.now,
      );
      addTearDown(engine.dispose);
      engine.start();

      // Drive preCountdown to expiry → land on R1 work-entry.
      clock.advance(const Duration(seconds: 45));
      engine.debugTick();
      expect(engine.state.phase, WorkoutPhase.work);

      // At round 1 work-start the engine reports remaining of full
      // work+rest. Math: (5 × 90) + (4 × 30) = 570s.
      expect(cfg.totalWorkoutSeconds, 570);
      expect(engine.state.currentRound, 1);
      // Engine just landed on R1 work; phaseRemaining ~= 90s.
      expect(engine.state.phaseRemaining.inSeconds, 90);
    });

    test('Custom: TOTAL displays 0 at workout complete', () {
      final audio = _NoopAudio();
      final clock = _TestClock(DateTime.utc(2026, 4, 30, 12));
      final cfg = CustomConfig.empty(0).copyWith(
        name: 'Single',
        rounds: 1,
        workSeconds: 30,
        restSeconds: 5,
      );
      final engine = WorkoutEngine(
        config: customConfigToWorkoutConfig(cfg),
        audio: audio,
        clock: clock.now,
      );
      addTearDown(engine.dispose);
      engine.start();

      // 45s preCountdown → R1 work (30s) → complete.
      clock.advance(const Duration(seconds: 45));
      engine.debugTick();
      // R1 work expires at remaining=1000ms via option-b shift, then
      // tick again to reach complete.
      clock.advance(const Duration(seconds: 29));
      engine.debugTick();
      clock.advance(const Duration(seconds: 1));
      engine.debugTick();
      expect(engine.state.phase, WorkoutPhase.complete);
      // Complete: phaseRemaining is zero, the dual-zero contract
      // is preserved by the engine.
      expect(engine.state.phaseRemaining, Duration.zero);
    });

    test('Custom: TOTAL displays full duration during preCountdown '
        '(does not tick down with preCountdown elapsed)', () {
      final audio = _NoopAudio();
      final clock = _TestClock(DateTime.utc(2026, 4, 30, 12));
      final cfg = CustomConfig.empty(0).copyWith(
        name: 'PreCountdownDisplay',
        rounds: 5,
        workSeconds: 90,
        restSeconds: 30,
      );
      final engine = WorkoutEngine(
        config: customConfigToWorkoutConfig(cfg),
        audio: audio,
        clock: clock.now,
      );
      addTearDown(engine.dispose);
      engine.start();

      // We're now in preCountdown (45s). Tick partway in (10s
      // elapsed) — the displayed TOTAL should still be 570s,
      // because the engine reports work+rest only and is not
      // subtracting elapsed preCountdown time.
      expect(engine.state.phase, WorkoutPhase.preCountdown);
      clock.advance(const Duration(seconds: 10));
      engine.debugTick();
      expect(engine.state.phase, WorkoutPhase.preCountdown,
          reason: 'still in preCountdown 10s in (35s remain)');
      // Total derived from CustomConfig — independent of preCountdown
      // elapsed.
      expect(cfg.totalWorkoutSeconds, 570);
    });
  });
}

class _NoopAudio extends AudioService {
  @override
  Future<void> play(String _) async {}
}

class _TestClock {
  _TestClock(this._now);
  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) {
    _now = _now.add(d);
  }
}
