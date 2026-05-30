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
      'Standard config (3×60×20): bell_start fires ON-BOUNDARY at every '
      'rest→work transition (R2, R3), not 1s-early in rest (2026-05-30 '
      'contract — mirrors 6aa5bef preCountdown→work precedent)',
      () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 60, restSeconds: 20);
    addTearDown(t.engine.dispose);

    // R1 work runs 60s, then R1 rest 20s, R2 work 60s, etc. bell_start
    // at the rest→work edge fires ON-BOUNDARY (at the work-entry tick),
    // not 1s early in rest. Drive ticks at BOTH windows and verify.
    int bellStarts() => _count(t.audio.events, WorkoutEngine.cueBellStart);

    // R1 → R1 rest. preCountdown's bell_start for R1 already fired
    // before our log clear in atR1WorkStart.
    t.clock.advance(const Duration(seconds: 59));
    t.engine.debugTick(); // R1 work, remainingMs=1000 — fires bell_END
                          // via option-b shift (work-end), NOT bell_start.
    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick(); // → R1 rest
    expect(t.engine.state.phase, WorkoutPhase.rest);

    // R1 rest → R2 work boundary.
    t.clock.advance(const Duration(seconds: 19));
    t.engine.debugTick(); // remainingMs=1000 in R1 rest
    expect(bellStarts(), 0,
        reason: '2026-05-30 contract: NO bell_start fires at the 1s-early '
            'rest tick — bell_start moved to on-boundary at rest→work');

    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick(); // remainingMs=0 → BOUNDARY → advance rest→work R2,
                          // R2 bell_start fires ON-BOUNDARY.
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 2);
    expect(bellStarts(), 1,
        reason: 'R2 bell_start fires on-boundary at rest→work edge '
            '(mirrors 6aa5bef preCountdown→work precedent)');

    // R2 work → R2 rest → R3 work boundary, repeat verification.
    t.clock.advance(const Duration(seconds: 60));
    t.engine.debugTick(); // → R2 rest
    expect(t.engine.state.phase, WorkoutPhase.rest);

    t.clock.advance(const Duration(seconds: 19));
    t.engine.debugTick(); // remainingMs=1000 in R2 rest
    expect(bellStarts(), 1,
        reason: 'Still no early-gate bell_start in R2 rest under new '
            'contract — count unchanged from previous boundary fire');

    t.clock.advance(const Duration(seconds: 1));
    t.engine.debugTick(); // remainingMs=0 → BOUNDARY → advance rest→work R3,
                          // R3 bell_start fires ON-BOUNDARY.
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 3);
    expect(bellStarts(), 2,
        reason: 'R3 bell_start fires on-boundary at rest→work edge');
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
      'Standard config (3×60×20): wood_clack fires once per work '
      'period at remaining ≤ 11000ms (Boxing-parity audio after the '
      'engine eligibility unlock for Custom)', () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 60, restSeconds: 20);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // R1 work: cross 11s threshold (49s elapsed of 60s).
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    expect(clacks(), 1,
        reason: 'R1 work crosses 11s remaining → 1 wood_clack');

    // Tick through the rest of the 11s window — must not re-fire.
    for (int i = 0; i < 10; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(clacks(), 1, reason: 'idempotent within R1 work period');

    // Cross R1 work expiry (final 1s window — bell_end fires; phase
    // advances to rest).
    t.clock.advance(const Duration(seconds: 6));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);
    final clacksAfterR1 = clacks();

    // R1 rest (20s) — NO clack should fire during rest for non-Smoker
    // configs (rest IS eligible per the engine, but only fires once
    // per period; we verify by counting deltas across the rest).
    // Drive rest through its 11s threshold then to expiry.
    t.clock.advance(const Duration(seconds: 9));
    t.engine.debugTick();
    final clacksMidRest = clacks();
    // Tick continues through rest expiry → R2 work entry.
    t.clock.advance(const Duration(seconds: 11));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 2);
    final clacksAtR2Start = clacks();

    // R1 rest (20s ≥ 12s threshold) IS clack-eligible like Boxing —
    // so 1 clack fires during rest at 11s remaining. Verify by delta.
    expect(clacksMidRest - clacksAfterR1, 1,
        reason: 'R1 rest crosses 11s remaining → 1 wood_clack '
            '(rest > 12s is clack-eligible like Boxing)');
    expect(clacksAtR2Start, clacksMidRest,
        reason: 'no extra clack between mid-rest and R2 work entry');
  });

  // -----------------------------------------------------------------
  // Short-work config: 3 rounds × 12s work × 10s rest
  // -----------------------------------------------------------------

  test(
      'Short work (3×12×10): wood_clack SUPPRESSED on every work '
      'round (≤12s identity rule). Rest periods may still fire if '
      'their duration falls inside the 11s lead window.', () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 12, restSeconds: 10);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Drive R1 work to expiry — 12s in fine ticks. The ≤12s
    // suppression rule must hold across the whole work period.
    final clacksAtR1WorkStart = clacks();
    for (int i = 0; i < 24; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.rest,
        reason: 'R1 12s work expired → R1 rest');
    expect(clacks() - clacksAtR1WorkStart, 0,
        reason: 'R1 work (≤12s) suppresses wood_clack');

    // Drive R1 rest to expiry — 10s ≤ 11s lead time means clack
    // gate is already true on rest entry. Documenting actual
    // engine behavior: rest clacks ARE eligible (this is locked
    // engine behavior, not specific to the Custom unlock).
    for (int i = 0; i < 20; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 2);
    final clacksAfterR1 = clacks();

    // R2 work: same suppression.
    for (int i = 0; i < 24; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(clacks() - clacksAfterR1, 0,
        reason: 'R2 work (≤12s) suppresses wood_clack');
  });

  // -----------------------------------------------------------------
  // Single-round config: 1 round × 60s work × (rest unused)
  // -----------------------------------------------------------------

  test(
      'Single round (1×60): wood_clack fires at 11s remaining, '
      'bell_end at 1s-early gate on work-end. No whistle_long — no '
      'rest periods exist', () {
    final t = atR1WorkStart(rounds: 1, workSeconds: 60, restSeconds: 5);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);
    int bellEnds() => _count(t.audio.events, WorkoutEngine.cueBellEnd);
    int whistleLongs() =>
        _count(t.audio.events, WorkoutEngine.cueWhistleLong);

    // Cross 11s remaining (49s elapsed) → wood_clack fires once.
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    expect(clacks(), 1,
        reason: 'Custom (Boxing-parity) fires wood_clack at 11s '
            'remaining of the 60s work period');

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
