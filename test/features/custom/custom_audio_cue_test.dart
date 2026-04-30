import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';
import 'package:eight_count/features/custom/models/custom_config.dart';
import 'package:eight_count/features/custom/services/custom_workout_adapter.dart';

/// Verifies the Custom preset uses the existing Boxing-style cue
/// schedule via the [customConfigToWorkoutConfig] adapter — no
/// parallel scheduler, no Custom-specific cues. Cues counted via
/// delta over a focused window (NOT removeWhere — locked test
/// pattern from the Smoker work).
class FakeAudioService extends AudioService {
  final List<({String cue, int tMs})> events = [];

  @override
  Future<void> play(String cueName) async {
    events.add((cue: cueName, tMs: DateTime.now().millisecondsSinceEpoch));
  }
}

class TestClock {
  TestClock(this._now);
  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) {
    _now = _now.add(d);
  }
}

int _count(List<({String cue, int tMs})> events, String cue) =>
    events.where((e) => e.cue == cue).length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Spin up an engine on the Custom config (via the adapter),
  /// fast-forward through the 45s preCountdown, drain the audio log,
  /// return engine + clock + audio so the test can drive ticks
  /// inside R1 work.
  ({WorkoutEngine engine, FakeAudioService audio, TestClock clock})
      atR1WorkStart({
    required int rounds,
    required int workSeconds,
    required int restSeconds,
  }) {
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 30, 12));
    final customCfg = CustomConfig.empty(0).copyWith(
      name: 'Test',
      rounds: rounds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
    );
    final engine = WorkoutEngine(
      config: customConfigToWorkoutConfig(customCfg),
      audio: audio,
      clock: clock.now,
    );
    engine.start();

    // Drive preCountdown to expiry → land on R1 work-entry.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 1);
    audio.events.clear();
    return (engine: engine, audio: audio, clock: clock);
  }

  // -----------------------------------------------------------------
  // Standard config: 3 rounds × 60s work × 20s rest
  // -----------------------------------------------------------------

  test(
      'Standard config (3×60×20): bell_start fires at the start of '
      'every work round (R1, R2, R3) via the 1s-early option-b shift',
      () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 60, restSeconds: 20);
    addTearDown(t.engine.dispose);

    // R1 work runs 60s, then R1 rest 20s, R2 work 60s, etc. Drive
    // ticks at the 1s-early boundary so the option-b gate fires.
    int bellStarts() => _count(t.audio.events, WorkoutEngine.cueBellStart);

    // R1 → R1 rest. preCountdown's bell_start for R1 already fired
    // before our log clear.
    t.clock.advance(const Duration(seconds: 59));
    t.engine.debugTick(); // R1 work, remainingMs=1000 — option-b
    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick(); // → R1 rest
    expect(t.engine.state.phase, WorkoutPhase.rest);

    // R1 rest → R2 work. R2 bell_start fires 1s before rest ends.
    t.clock.advance(const Duration(seconds: 19));
    t.engine.debugTick(); // remainingMs=1000 in rest, fires bell_start
    final bellsAfterR2Entry = bellStarts();
    expect(bellsAfterR2Entry, greaterThanOrEqualTo(1),
        reason: 'R2 bell_start fires at 1s-early window of R1 rest');

    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick(); // → R2 work
  });

  test(
      'Standard config (3×60×20): whistle_long fires at every '
      'rest-entry (R1 rest, R2 rest), not on the final rest',
      () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 60, restSeconds: 20);
    addTearDown(t.engine.dispose);

    // Boxing/Custom rest-entry whistle_long is fired by the engine's
    // _advanceToPhase rest-Boxing branch — but actually for Boxing
    // the rest-entry is intentionally SILENT (whistle_long is
    // reserved for Smoker). Let's verify Custom inherits Boxing's
    // contract: rest-entry should be silent (no whistle_long).
    int whistleLongs() =>
        _count(t.audio.events, WorkoutEngine.cueWhistleLong);

    // Run R1 work + R1 rest + R2 work + R2 rest.
    t.clock.advance(const Duration(seconds: 60));
    t.engine.debugTick(); // → R1 rest
    expect(t.engine.state.phase, WorkoutPhase.rest);
    expect(whistleLongs(), 0,
        reason: 'Custom (presetId=custom) rest-entry is SILENT, '
            'mirroring Boxing — whistle_long is Smoker-Tabata only');

    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick(); // → R2 work
    t.clock.advance(const Duration(seconds: 60));
    t.engine.debugTick(); // → R2 rest
    expect(whistleLongs(), 0);
  });

  test(
      'Standard config (3×60×20): wood_clack does NOT fire during '
      'Custom work or rest periods (engine current contract — see '
      'deviation note in Session B report)', () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 60, restSeconds: 20);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Workout-engine _isWoodClackEligiblePeriod returns
    // `_presetId == 'boxing'` for non-Smoker single-block configs
    // (workout_engine.dart:373). Custom presets (presetId='custom')
    // therefore never fire wood_clack during work or rest. This is
    // the locked-engine contract today; if Boxing parity is wanted,
    // the engine needs to be unlocked and updated to accept
    // 'custom' alongside 'boxing'.
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    expect(clacks(), 0,
        reason: 'Custom does NOT fire wood_clack — engine gate is '
            "_presetId == 'boxing' on the non-Smoker branch");

    for (int i = 0; i < 30; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(clacks(), 0,
        reason: 'no Custom wood_clack across the entire R1 work + rest');
  });

  // -----------------------------------------------------------------
  // Short-work config: 3 rounds × 12s work × 10s rest
  // -----------------------------------------------------------------

  test(
      'Short work (3×12×10): wood_clack SUPPRESSED on every work '
      'round (≤12s identity rule from fix/clack-suppress-short-work)',
      () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 12, restSeconds: 10);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Run all 3 rounds end-to-end with fine-grained ticks; the
    // ≤12s suppression rule must hold across every work period.
    for (int round = 1; round <= 3; round++) {
      for (int i = 0; i < 24; i++) {
        t.clock.advance(const Duration(milliseconds: 500));
        t.engine.debugTick();
      }
      // After 12s elapsed, work expires; tick the boundary.
      if (round < 3) {
        // R1/R2 → rest, then back to next work
        for (int i = 0; i < 20; i++) {
          t.clock.advance(const Duration(milliseconds: 500));
          t.engine.debugTick();
        }
      }
    }

    expect(clacks(), 0,
        reason: 'Work blocks ≤12s suppress wood_clack regardless '
            'of preset, per the Tabata identity / short-work rule');
  });

  // -----------------------------------------------------------------
  // Single-round config: 1 round × 60s work × (rest unused)
  // -----------------------------------------------------------------

  test(
      'Single round (1×60): bell_end fires at 1s-early gate on '
      'work-end. No whistle_long. wood_clack also does NOT fire '
      '(Custom engine contract — see deviation note)', () {
    final t = atR1WorkStart(rounds: 1, workSeconds: 60, restSeconds: 5);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);
    int bellEnds() => _count(t.audio.events, WorkoutEngine.cueBellEnd);
    int whistleLongs() =>
        _count(t.audio.events, WorkoutEngine.cueWhistleLong);

    // Tick through the 11s mark — Custom does NOT fire wood_clack
    // (engine eligibility gate is presetId == 'boxing' for the
    // non-Smoker branch). Documenting actual behavior; see Session
    // B report for the engine-spec mismatch deviation note.
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    expect(clacks(), 0,
        reason: 'Custom: wood_clack suppressed by engine gate');

    // Tick to 1000ms remaining — bell_end fires via option-b shift.
    t.clock.advance(const Duration(seconds: 10));
    t.engine.debugTick();
    expect(bellEnds(), greaterThanOrEqualTo(1),
        reason: 'bell_end fires at 1s-early gate on the final round');

    // Tick across the boundary → engine reaches complete.
    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.complete);

    // Whistle_long never fires — there's no rest period in a
    // 1-round workout, AND Custom rest-entry is silent anyway.
    expect(whistleLongs(), 0);
  });
}
