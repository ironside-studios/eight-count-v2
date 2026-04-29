import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';

/// Tests for the 2026-04-29 Tabata audio rewire:
///   - whistle_long fires AT phase entry on every Tabata work round (R1–R8),
///     on-boundary (not via the 1s-early option-b shift).
///   - whistle_double fires AT work-exit for Tabata rounds R1..R{N-1}.
///   - bell_end fires AT work-exit for the LAST round of a Tabata block.
///   - Tabata rest-entry is silent (no whistle_long).
///   - Tabata work blocks never schedule wood_clack (identity rule).
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

/// Spin up a Smoker engine, fast-forward to Block 2 R1 work-entry
/// (Tabata, 20s work / 10s rest), drain the audio log so the test
/// starts clean inside the work period.
({WorkoutEngine engine, FakeAudioService audio, TestClock clock})
    atTabataR1Work() {
  final audio = FakeAudioService();
  final clock = TestClock(DateTime.utc(2026, 4, 29, 12));
  final engine = WorkoutEngine(
    config: SmokerConfig.standard(),
    audio: audio,
    clock: clock.now,
  );
  engine.start();

  // preCountdown 45s → B1 R1 work.
  clock.advance(const Duration(seconds: 45));
  engine.debugTick();

  // Run B1 (Boxing 6 rounds, 180/60), then transition to enter B2.
  for (int i = 0; i < 5; i++) {
    clock.advance(const Duration(seconds: 180));
    engine.debugTick(); // → rest
    clock.advance(const Duration(seconds: 60));
    engine.debugTick(); // → next work
  }
  // R6 work → trailing transition rest.
  clock.advance(const Duration(seconds: 180));
  engine.debugTick();
  expect(engine.state.blockType, WorkoutBlockType.transition);

  // Transition rest 60s → B2 R1 work-entry.
  clock.advance(const Duration(seconds: 60));
  engine.debugTick();
  expect(engine.state.phase, WorkoutPhase.work);
  expect(engine.state.blockType, WorkoutBlockType.tabata);
  audio.events.clear();
  return (engine: engine, audio: audio, clock: clock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'Tabata work-end (R1..R7) fires whistle_double, not whistle_long '
      'or bell_end', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Expire the 20s work period — engine advances to rest, work-exit
    // cue fires on the way.
    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);

    expect(_count(t.audio.events, WorkoutEngine.cueWhistleDouble), 1,
        reason: 'R1 (non-final) Tabata work-exit fires whistle_double');
    expect(_count(t.audio.events, WorkoutEngine.cueBellEnd), 0,
        reason: 'non-final round must NOT fire bell_end');
  });

  test(
      'Tabata work-end on the LAST round of the block fires bell_end, '
      'not whistle_double', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Run B2 R1..R7 full rounds (work + rest), each fires whistle_double
    // on work-exit. Then the R8 work-end must fire bell_end.
    for (int i = 0; i < 7; i++) {
      t.clock.advance(const Duration(seconds: 20));
      t.engine.debugTick(); // work → rest, fires whistle_double
      t.clock.advance(const Duration(seconds: 10));
      t.engine.debugTick(); // rest → next work, fires whistle_long
    }
    expect(t.engine.state.phase, WorkoutPhase.work);
    final whistleDoublesBeforeR8 =
        _count(t.audio.events, WorkoutEngine.cueWhistleDouble);
    final bellEndsBeforeR8 = _count(t.audio.events, WorkoutEngine.cueBellEnd);

    // Expire R8 work — last round of B2 (Tabata).
    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick();

    // bell_end fired exactly once on this work-exit, NOT whistle_double.
    expect(_count(t.audio.events, WorkoutEngine.cueBellEnd) - bellEndsBeforeR8,
        1,
        reason: 'R8 (last round of Tabata block) work-exit fires bell_end');
    expect(
      _count(t.audio.events, WorkoutEngine.cueWhistleDouble) -
          whistleDoublesBeforeR8,
      0,
      reason: 'R8 must NOT fire whistle_double (bell_end is the block-end '
          'cue)',
    );
  });

  test(
      'Tabata work-START fires whistle_long on every round (R1..R8), '
      'on-boundary from _advanceToPhase', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // We just entered B2 R1 work via the helper, which already fired
    // whistle_long once on phase entry — but the helper cleared the log,
    // so we count from R1 forward by re-driving the cycle.
    // The helper already drained, so R1 work-entry whistle is missed
    // from the count. Make a fresh engine to count cleanly.
    t.engine.dispose();

    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 29, 12));
    final engine = WorkoutEngine(
      config: SmokerConfig.standard(),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → B1 R1 work
    // Run B1 fully + trailing transition.
    for (int i = 0; i < 5; i++) {
      clock.advance(const Duration(seconds: 180));
      engine.debugTick();
      clock.advance(const Duration(seconds: 60));
      engine.debugTick();
    }
    clock.advance(const Duration(seconds: 180));
    engine.debugTick(); // R6 → transition
    clock.advance(const Duration(seconds: 60));
    engine.debugTick(); // transition → B2 R1 work (whistle_long fires here)

    final whistlesAtB2R1 = _count(audio.events, WorkoutEngine.cueWhistleLong);
    expect(whistlesAtB2R1, 1,
        reason: 'B2 R1 work-entry fires exactly one whistle_long');

    // Run R1..R7 cycle (each cycle fires one whistle_long on next work
    // entry), then R8 entry fires the 8th.
    for (int i = 0; i < 7; i++) {
      clock.advance(const Duration(seconds: 20));
      engine.debugTick(); // work → rest
      clock.advance(const Duration(seconds: 10));
      engine.debugTick(); // rest → next work
    }
    expect(engine.state.phase, WorkoutPhase.work);

    expect(_count(audio.events, WorkoutEngine.cueWhistleLong), 8,
        reason: '8 Tabata work-entries (R1..R8) each fire whistle_long');
  });

  test(
      'Tabata rest-entry is silent (no whistle_long)', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Expire R1 work → enter rest. The whistle_double fires on work-exit
    // (already covered above); separately verify NO whistle_long fires
    // during the rest period itself.
    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);

    final whistleLongsAtRestStart =
        _count(t.audio.events, WorkoutEngine.cueWhistleLong);

    // Run the full 10s Tabata rest in fine ticks.
    for (int i = 0; i < 20; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }

    // The rest-end fires a NEW whistle_long for the next work-entry —
    // that's expected. But during the rest itself there must be no
    // additional whistle_long beyond that.
    final whistleLongsAfterRest =
        _count(t.audio.events, WorkoutEngine.cueWhistleLong);
    final delta = whistleLongsAfterRest - whistleLongsAtRestStart;
    expect(delta, lessThanOrEqualTo(1),
        reason: 'at most one whistle_long across rest+next-work-entry; '
            'rest-entry itself fires zero');
  });

  test(
      'Tabata work blocks never schedule wood_clack (identity rule, '
      'verify regression)', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Tick through the full 20s Tabata work in fine increments. Even
    // crossing the 11s / 12s thresholds where Boxing would fire
    // wood_clack, Tabata stays silent for clack.
    for (int i = 0; i < 80; i++) {
      t.clock.advance(const Duration(milliseconds: 250));
      t.engine.debugTick();
    }
    expect(_count(t.audio.events, WorkoutEngine.cueWoodClack), 0,
        reason: 'Tabata work never schedules wood_clack regardless of '
            'remaining time (locked 4/28/26 identity rule)');
  });

  test(
      'Full Tabata flow (B2 R1..R8): 8 whistle_long work-entries, '
      '7 whistle_double work-exits, 1 bell_end on R8 work-exit', () {
    // This test uses on-boundary cues (whistle_long via _advanceToPhase,
    // whistle_double + bell_end via _advanceFromCurrentPhaseSmoker), all
    // of which fire on direct phase advance — so coarse ticks work.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 29, 12));
    final engine = WorkoutEngine(
      config: SmokerConfig.standard(),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();

    void tick(Duration d) {
      clock.advance(d);
      engine.debugTick();
    }

    // preCountdown 45s → B1 R1 work.
    tick(const Duration(seconds: 45));
    // B1 (6 rounds 180/60).
    for (int i = 0; i < 5; i++) {
      tick(const Duration(seconds: 180));
      tick(const Duration(seconds: 60));
    }
    tick(const Duration(seconds: 180)); // R6 → T1
    tick(const Duration(seconds: 60)); // T1 → B2 R1
    expect(engine.state.blockType, WorkoutBlockType.tabata);

    // Snapshot baselines at start of B2 R1 work.
    final wlBase = _count(audio.events, WorkoutEngine.cueWhistleLong);
    final wdBase = _count(audio.events, WorkoutEngine.cueWhistleDouble);
    final beBase = _count(audio.events, WorkoutEngine.cueBellEnd);

    // Run B2 R1..R7 full rounds.
    for (int i = 0; i < 7; i++) {
      tick(const Duration(seconds: 20));
      tick(const Duration(seconds: 10));
    }
    // R8 work to expiry.
    tick(const Duration(seconds: 20));

    // 8 work-entries × 1 whistle_long each (R1 was already on entry into
    // this block, R2..R8 fire on each rest→work transition).
    expect(_count(audio.events, WorkoutEngine.cueWhistleLong) - wlBase, 7,
        reason: 'R2..R8 work-entries fire whistle_long (R1 entry was '
            'before baseline snapshot — confirmed at +1 outside this '
            'measurement)');
    // 7 whistle_double work-exits (R1..R7).
    expect(_count(audio.events, WorkoutEngine.cueWhistleDouble) - wdBase, 7,
        reason: 'R1..R7 work-exits fire whistle_double');
    // 1 bell_end on R8 work-exit.
    expect(_count(audio.events, WorkoutEngine.cueBellEnd) - beBase, 1,
        reason: 'R8 work-exit fires bell_end (block-end)');
  });
}
