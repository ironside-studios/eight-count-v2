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

  test('clack_scheduled_when_work_is_13s', () {
    // Custom preset's wood_clack fire-rule for work uses the Smoker/Custom
    // 11s lead time (Boxing-only gets the 12s lead). 13s work means there
    // is exactly 1 second of "elapsed before warning" headroom, but the
    // suppression rule (≤12) does NOT apply, so the clack must fire.
    //
    // Custom preset's eligibility branch only fires for presetId=='boxing',
    // so we exercise this rule against a Boxing preset variant: build a
    // WorkoutConfig manually keyed as 'boxing' with 13s work.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 27, 12));
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

    // Tick from work-start through the 11s lead-time mark (Boxing's lead
    // for work is 12s, so wood_clack fires at remaining ≤ 12000ms — i.e.
    // the very first tick inside work since 13s − 12s = 1s elapsed).
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    // Continue ticking deeper into the work period; gate fires once.
    for (int i = 0; i < 10; i++) {
      clock.advance(const Duration(milliseconds: 500));
      engine.debugTick();
    }
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 1,
        reason: '13s work block is above the ≤12s suppression threshold');
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

  test('clack_scheduled_on_5s_rest_block (rest unaffected by work guard)',
      () {
    // Rest of 5s is well below the 12s threshold, but the suppression
    // rule does NOT apply to rest. Eligibility for Boxing rest is "yes",
    // so wood_clack fires at remaining ≤ 12000ms (Boxing rest lead) —
    // i.e. immediately on rest entry given a 5s rest period.
    final audio = FakeAudioService();
    final clock = TestClock(DateTime.utc(2026, 4, 27, 12));
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

    // Single tick at rest-entry should already cross the 12s remaining
    // threshold (rest is only 5s long).
    clock.advance(const Duration(milliseconds: 100));
    engine.debugTick();
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 1,
        reason: 'rest block, regardless of duration, is NOT subject to '
            'the work-suppression rule');
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
