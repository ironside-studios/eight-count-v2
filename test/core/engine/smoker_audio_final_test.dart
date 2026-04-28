import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';

/// Tests for the 2026-04-28 Smoker audio fixes:
///   - Bug 3: whistle_double scheduling at 10s mark of Tabata work
///   - (Bug 5 hold + Bug 4 display formula tests live alongside the
///     timer-screen tests — those touch the UI layer, not the engine.)
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

  /// Spin up a Smoker engine, fast-forward to Block 2 R1 work-entry
  /// (Tabata, 20s work / 10s rest), drain the audio log so the test
  /// starts clean inside the work period.
  ({WorkoutEngine engine, FakeAudioService audio, TestClock clock})
      atTabataR1Work() {
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 28, 12));
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

  test(
      'Bug 3 — whistle_double does not fire above the 11000ms gate', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Just entered 20s Tabata work. No whistle_double yet.
    expect(_count(t.audio.events, WorkoutEngine.cueWhistleDouble), 0);

    // Advance to 8s elapsed (12s remaining) — above the 11000ms gate.
    t.clock.advance(const Duration(seconds: 8));
    t.engine.debugTick();
    expect(_count(t.audio.events, WorkoutEngine.cueWhistleDouble), 0,
        reason: 'remainingMs=12000 is above the 11000 gate; no fire yet');
  });

  test(
      'Bug 3 — whistle_double fires exactly at the 11000ms boundary on '
      'a fresh Tabata work period', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Cross the 11000ms remaining boundary. 20s − 9s = 11s remaining.
    t.clock.advance(const Duration(seconds: 9));
    t.engine.debugTick();
    expect(_count(t.audio.events, WorkoutEngine.cueWhistleDouble), 1,
        reason: 'remainingMs=11000 triggers the whistle_double gate');

    // Continue ticking inside the 11s window — must NOT re-fire.
    for (int i = 0; i < 30; i++) {
      t.clock.advance(const Duration(milliseconds: 250));
      t.engine.debugTick();
    }
    expect(_count(t.audio.events, WorkoutEngine.cueWhistleDouble), 1,
        reason: 'idempotent within the same Tabata work period');
  });

  test(
      'Bug 3 — whistle_double does NOT fire during Tabata REST (rest is '
      '10s; gate guards on _phase == work)', () {
    final t = atTabataR1Work();
    addTearDown(t.engine.dispose);

    // Run the whole 20s work period (will fire whistle_double once on
    // the way), then advance into rest.
    t.clock.advance(const Duration(seconds: 20));
    t.engine.debugTick();
    expect(t.engine.state.phase, WorkoutPhase.rest);
    final preRest = _count(t.audio.events, WorkoutEngine.cueWhistleDouble);

    // Tick across the entire 10s Tabata rest.
    for (int i = 0; i < 20; i++) {
      t.clock.advance(const Duration(milliseconds: 500));
      t.engine.debugTick();
    }
    final postRest = _count(t.audio.events, WorkoutEngine.cueWhistleDouble);
    expect(postRest - preRest, 0,
        reason: 'whistle_double is gated on _phase == work; Tabata rest '
            'never schedules it regardless of remaining time');
  });

  test(
      'Bug 3 — whistle_double fires in every Tabata work round of a full '
      'Smoker workout (8 rounds × 2 Tabata blocks = 16 fires)', () {
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 28, 12));
    final engine = WorkoutEngine(
      config: SmokerConfig.standard(),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();

    // Drive the entire Smoker flow with coarse ticks — work, rest,
    // transition. The exact tick cadence doesn't matter for cue counting
    // because the engine fires cues based on the (clock, phaseEndsAt)
    // delta on each tick.
    void runWork(Duration d) {
      clock.advance(d);
      engine.debugTick();
    }

    // preCountdown → B1 R1 work.
    runWork(const Duration(seconds: 45));

    // B1 Boxing: 6 rounds, 180/60.
    for (int i = 0; i < 5; i++) {
      runWork(const Duration(seconds: 180));
      runWork(const Duration(seconds: 60));
    }
    runWork(const Duration(seconds: 180)); // R6 work → T1
    runWork(const Duration(seconds: 60)); // T1 → B2 R1

    // B2 Tabata: 8 rounds, 20/10.
    for (int i = 0; i < 7; i++) {
      runWork(const Duration(seconds: 20));
      runWork(const Duration(seconds: 10));
    }
    runWork(const Duration(seconds: 20)); // R8 work → T2
    runWork(const Duration(seconds: 60)); // T2 → B3 R1

    // B3 Boxing: 6 rounds.
    for (int i = 0; i < 5; i++) {
      runWork(const Duration(seconds: 180));
      runWork(const Duration(seconds: 60));
    }
    runWork(const Duration(seconds: 180)); // R6 work → T3
    runWork(const Duration(seconds: 60)); // T3 → B4 R1

    // B4 Tabata: 8 rounds.
    for (int i = 0; i < 7; i++) {
      runWork(const Duration(seconds: 20));
      runWork(const Duration(seconds: 10));
    }
    runWork(const Duration(seconds: 20)); // R8 work → complete

    expect(engine.state.phase, WorkoutPhase.complete);
    expect(_count(audio.events, WorkoutEngine.cueWhistleDouble), 16,
        reason: '8 Tabata work rounds × 2 Tabata blocks = 16 fires');
    // Sanity: no whistle_double during Boxing blocks (gated on Tabata).
    // We can't directly count Boxing work clack-vs-whistle without a
    // per-event phase tag, but the total of 16 across the full flow with
    // 12 Boxing work rounds + 16 Tabata work rounds confirms exclusivity.
  });
}
