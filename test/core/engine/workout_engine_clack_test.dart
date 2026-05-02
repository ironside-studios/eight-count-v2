import 'package:flutter_test/flutter_test.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';

/// Tests for the "suppress wood_clack on work blocks ≤ 12s" rule. The
/// 10s-out warning is meaningless when the work period is barely longer
/// than the warning itself. Rule applies to ALL presets uniformly; rest,
/// GET READY, and transitions are NOT affected.
class FakeAudioService extends AudioService {
  final List<String> playLog = <String>[];

  @override
  Future<void> play(String cueName) async {
    playLog.add(cueName);
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

int _count(List<String> log, String cue) =>
    log.where((c) => c == cue).length;

/// Helper: spin up an engine with a Custom WorkoutConfig of the given
/// work/rest seconds, advance past the 45s preCountdown into round 1
/// work, return engine + audio so the test can drive it deterministically.
({WorkoutEngine engine, FakeAudioService audio, TestClock clock})
    _engineAtRound1Work({
  required int workSeconds,
  required int restSeconds,
  int rounds = 3,
}) {
  final audio = FakeAudioService();
  final clock = TestClock(DateTime.utc(2026, 4, 27, 12));
  final engine = WorkoutEngine(
    config: WorkoutConfig.custom(
      rounds: rounds,
      workSeconds: workSeconds,
      restSeconds: restSeconds,
    ),
    audio: audio,
    clock: clock.now,
  );
  engine.start();
  // Burn through the 45s preCountdown (which fires its OWN wood_clack at
  // remaining ≤12s — that's a separate warning we don't care about for
  // the work-suppression assertions). Drain the play log AFTER landing
  // in work so each test starts with a clean slate.
  clock.advance(const Duration(seconds: 45));
  engine.debugTick();
  expect(engine.state.phase, WorkoutPhase.work);
  audio.playLog.clear();
  return (engine: engine, audio: audio, clock: clock);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clack_suppressed_when_work_period_is_13s_below_30s_threshold',
      () {
    // Updated 2026-05-02: prior contract was the work-only ≤12s rule
    // (4/28/26) under which 13s work fired wood_clack normally. The new
    // ≤30s period-total rule (locked V2 5/2/26 — see workout_engine.dart
    // _isWoodClackEligiblePeriod) suppresses wood_clack on ANY period
    // (work or rest) ≤30s. 13s work is well below the new threshold,
    // so this test now asserts suppression rather than firing.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 5, 2, 12));
    final engine = WorkoutEngine(
      config: const WorkoutConfig(
        presetId: 'boxing',
        totalRounds: 3,
        workDuration: Duration(seconds: 13),
        restDuration: Duration(seconds: 30),
        preCountdown: Duration(seconds: 45),
      ),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1 (13s)
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playLog.clear();

    // Tick from work-start through the entire 13s window in fine
    // increments. Under the ≤30s rule, no wood_clack should fire at
    // any point.
    for (int i = 0; i < 26; i++) {
      clock.advance(const Duration(milliseconds: 500));
      engine.debugTick();
    }
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 0,
        reason: '13s work (≤30s) suppresses wood_clack under the '
            '5/2/26 rule');
  });

  test('clack_suppressed_when_work_is_12s', () {
    // 12s work block — the comparison is `<=` so 12 is suppressed.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 27, 12));
    final engine = WorkoutEngine(
      config: const WorkoutConfig(
        presetId: 'boxing',
        totalRounds: 3,
        workDuration: Duration(seconds: 12),
        restDuration: Duration(seconds: 30),
        preCountdown: Duration(seconds: 45),
      ),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playLog.clear();

    // Tick continuously from the start of the 12s work to its end. No
    // wood_clack should ever fire during this work period.
    for (int i = 0; i < 24; i++) {
      clock.advance(const Duration(milliseconds: 500));
      engine.debugTick();
    }
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 0,
        reason: '12s work block must suppress wood_clack (≤12 rule, '
            'inclusive)');
  });

  test('clack_suppressed_when_work_is_10s', () {
    // 10s work block — well below threshold, no warning.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 27, 12));
    final engine = WorkoutEngine(
      config: const WorkoutConfig(
        presetId: 'boxing',
        totalRounds: 3,
        workDuration: Duration(seconds: 10),
        restDuration: Duration(seconds: 30),
        preCountdown: Duration(seconds: 45),
      ),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playLog.clear();

    for (int i = 0; i < 20; i++) {
      clock.advance(const Duration(milliseconds: 500));
      engine.debugTick();
    }
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 0,
        reason: '10s work block must suppress wood_clack');
  });

  test('clack_suppressed_on_5s_rest_period_below_30s_threshold', () {
    // Updated 2026-05-02: prior contract had a "work-only" suppression
    // rule, so 5s rest blocks DID fire wood_clack on entry (gate was
    // open immediately because 5s ≤ 11s lead). The new ≤30s rule
    // (locked V2 5/2/26 — see workout_engine.dart
    // _isWoodClackEligiblePeriod) applies to BOTH work and rest, so
    // 5s rest is now suppressed entirely. Renamed + flipped from the
    // old "rest unaffected by work guard" assertion.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 5, 2, 12));
    final engine = WorkoutEngine(
      config: const WorkoutConfig(
        presetId: 'boxing',
        totalRounds: 3,
        workDuration: Duration(seconds: 60),
        restDuration: Duration(seconds: 5),
        preCountdown: Duration(seconds: 45),
      ),
      audio: audio,
      clock: clock.now,
    );
    addTearDown(engine.dispose);
    engine.start();
    // Advance past preCountdown → R1 work, then through R1 work → R1 rest.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    clock.advance(const Duration(seconds: 60));
    engine.debugTick(); // → R1 rest (5s)
    expect(engine.state.phase, WorkoutPhase.rest);
    audio.playLog.clear();

    // Tick across the entire 5s rest in fine increments — the gate
    // returns false at duration ≤30s, so nothing should fire.
    for (int i = 0; i < 12; i++) {
      clock.advance(const Duration(milliseconds: 500));
      engine.debugTick();
    }
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 0,
        reason: '5s rest (≤30s) suppresses wood_clack under the '
            '5/2/26 rule');
  });

  // Sanity check that the helper shape matches expectations — guards
  // future refactors.
  test('engine_helper_smoke_test', () {
    final t = _engineAtRound1Work(workSeconds: 30, restSeconds: 10);
    addTearDown(t.engine.dispose);
    expect(t.engine.state.phase, WorkoutPhase.work);
    expect(t.engine.state.phaseDuration, const Duration(seconds: 30));
  });
}
