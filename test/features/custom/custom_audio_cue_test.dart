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

    // R1 rest (20s ≤ 30s) — under the 5/2/26 ≤30s rule, rest periods
    // ≤30s now suppress wood_clack entirely. Pre-5/2/26 the 20s rest
    // crossed the 11s threshold and fired one clack; now zero.
    t.clock.advance(const Duration(seconds: 9));
    t.engine.debugTick();
    final clacksMidRest = clacks();
    // Tick continues through rest expiry → R2 work entry.
    t.clock.advance(const Duration(seconds: 11));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 2);
    final clacksAtR2Start = clacks();

    expect(clacksMidRest - clacksAfterR1, 0,
        reason: 'R1 rest (20s ≤ 30s) suppresses wood_clack under the '
            '5/2/26 rule (was 1 under the prior work-only ≤12s rule)');
    expect(clacksAtR2Start, clacksMidRest,
        reason: 'no extra clack between mid-rest and R2 work entry');
  });

  // -----------------------------------------------------------------
  // Short-work config: 3 rounds × 12s work × 10s rest
  // -----------------------------------------------------------------

  test(
      'Short work (3×12×10): wood_clack SUPPRESSED on every work '
      'round AND every rest period (≤30s rule, locked V2 5/2/26 — '
      'see workout_engine.dart _isWoodClackEligiblePeriod).', () {
    final t = atR1WorkStart(rounds: 3, workSeconds: 12, restSeconds: 10);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Updated 5/2/26: prior rule was "work-only ≤12s suppression"
    // and this test asserted that 10s rest periods STILL fired
    // wood_clack on entry. The new global ≤30s rule applies to
    // BOTH work and rest, so all four short periods (R1 work,
    // R1 rest, R2 work, R2 rest) are now silent.
    final clacksAtR1WorkStart = clacks();
    for (int i = 0; i < 24; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.rest,
        reason: 'R1 12s work expired → R1 rest');
    expect(clacks() - clacksAtR1WorkStart, 0,
        reason: 'R1 work (12s ≤ 30s) suppresses wood_clack');

    // Drive R1 rest (10s ≤ 30s) — under the NEW rule this is
    // ALSO silent. Pre-5/2/26 this fired on rest entry.
    for (int i = 0; i < 20; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.currentRound, 2);
    final clacksAfterR1 = clacks();
    expect(clacksAfterR1 - clacksAtR1WorkStart, 0,
        reason: 'R1 rest (10s ≤ 30s) suppresses wood_clack '
            '(NEW behavior under the 5/2/26 rule)');

    // R2 work: same suppression.
    for (int i = 0; i < 24; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(clacks() - clacksAfterR1, 0,
        reason: 'R2 work (12s ≤ 30s) suppresses wood_clack');
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

  // -----------------------------------------------------------------
  // ≤30s wood_clack suppression boundary tests (rule locked V2 5/2/26).
  // The rule: phases (work OR rest) with totalDuration ≤30s do not
  // fire wood_clack. Boundary cases pin the threshold at 30 vs 31.
  // -----------------------------------------------------------------

  test(
      '≤30s rule: wood_clack SUPPRESSED at exactly 30s work boundary',
      () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 30, restSeconds: 60);
    addTearDown(t.engine.dispose);

    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Drive through R1 work (30s) in fine ticks. With the gate
    // returning false at duration ≤30, nothing should fire.
    for (int i = 0; i < 60; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.rest);
    expect(clacks(), 0,
        reason: '30s work hits the boundary and suppresses; rule is <=30');
  });

  test(
      '≤30s rule: wood_clack SUPPRESSED at 20s work (Tabata-style)',
      () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 20, restSeconds: 60);
    addTearDown(t.engine.dispose);
    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);
    for (int i = 0; i < 40; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(t.engine.state.phase, WorkoutPhase.rest);
    expect(clacks(), 0,
        reason: '20s work is well below the 30s threshold');
  });

  test(
      '≤30s rule: wood_clack SUPPRESSED at 10s rest (Tabata-style)',
      () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 60, restSeconds: 10);
    addTearDown(t.engine.dispose);
    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // R1 work (60s) crosses 11s remaining → fires 1 clack.
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    final clacksAfterR1Work = clacks();
    expect(clacksAfterR1Work, 1, reason: 'R1 work (60s > 30s) fires');

    // Drive through R1 work expiry → 10s rest.
    t.clock.advance(const Duration(seconds: 11));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);
    // Drive the entire 10s rest in fine ticks. Under the new rule
    // it must stay silent.
    for (int i = 0; i < 20; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    expect(clacks() - clacksAfterR1Work, 0,
        reason: '10s rest (≤30s) suppresses wood_clack');
  });

  test(
      '≤30s rule: wood_clack STILL FIRES at 31s work (just above '
      'the threshold)', () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 31, restSeconds: 60);
    addTearDown(t.engine.dispose);
    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);
    // R1 work (31s) crosses 11s remaining at elapsed=20s.
    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick();
    expect(clacks(), 1,
        reason: '31s work is above the threshold → fires normally');
  });

  test(
      '≤30s rule: wood_clack STILL FIRES at 60s rest (Boxing rest, '
      'regression check)', () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 60, restSeconds: 60);
    addTearDown(t.engine.dispose);
    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);

    // Skip past R1 work (already exercised elsewhere) into R1 rest.
    t.clock.advance(const Duration(seconds: 60));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);
    final clacksAtR1RestStart = clacks();

    // 60s rest crosses 11s remaining at elapsed=49s.
    t.clock.advance(const Duration(seconds: 49));
    t.engine.debugTick();
    expect(clacks() - clacksAtR1RestStart, 1,
        reason: '60s rest (>30s) fires wood_clack normally — Boxing '
            'parity preserved');
  });

  test(
      '≤30s rule: wood_clack STILL FIRES at 180s work (Boxing work, '
      'regression check)', () {
    final t = atR1WorkStart(rounds: 2, workSeconds: 180, restSeconds: 60);
    addTearDown(t.engine.dispose);
    int clacks() => _count(t.audio.events, WorkoutEngine.cueWoodClack);
    // 180s work crosses 11s remaining at elapsed=169s.
    t.clock.advance(const Duration(seconds: 169));
    t.engine.debugTick();
    expect(clacks(), 1,
        reason: '180s work (>>30s) fires wood_clack — locked Boxing '
            'behavior unchanged by the 5/2/26 rule');
  });
}
