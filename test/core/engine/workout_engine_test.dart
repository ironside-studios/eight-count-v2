import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';

class FakeAudioService extends AudioService {
  final List<String> playedCues = <String>[];

  @override
  Future<void> play(String cueName) async {
    playedCues.add(cueName);
  }
}

/// Minimal mutable clock for deterministic time control in tests.
class TestClock {
  TestClock(this._now);

  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) {
    _now = _now.add(d);
  }
}

void main() {
  // Ticker requires SchedulerBinding. flutter_test's default binding provides it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService audio;
  late TestClock clock;
  late WorkoutEngine engine;

  setUp(() {
    audio = FakeAudioService();
    clock = TestClock(DateTime.utc(2026, 1, 1, 12));
    engine = WorkoutEngine(
      config: WorkoutConfig.boxing(),
      audio: audio,
      clock: clock.now,
    );
  });

  tearDown(() {
    engine.dispose();
  });

  test('start() puts engine in preCountdown phase with currentRound == 0', () {
    engine.start();

    final s = engine.state;
    expect(s.phase, WorkoutPhase.preCountdown);
    expect(s.currentRound, 0);
    expect(s.totalRounds, 12);
    expect(s.isPaused, isFalse);
    expect(s.phaseDuration, const Duration(seconds: 45));
    expect(s.phaseRemaining, const Duration(seconds: 45));
  });

  test(
      'After preCountdown elapses, engine is in work phase, currentRound == 1, '
      'bell_start was played', () {
    engine.start();

    // Hop past the 11s warning threshold.
    clock.advance(const Duration(seconds: 35));
    engine.debugTick();

    // Hop past the expiry boundary.
    clock.advance(const Duration(seconds: 15));
    engine.debugTick();

    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 1);
    expect(audio.playedCues.contains(WorkoutEngine.cueBellStart), isTrue);
  });

  test('wood_clack fires exactly once per phase at the 11s threshold', () {
    engine.start();

    // Cross the 11s boundary.
    clock.advance(const Duration(seconds: 35));
    engine.debugTick();

    // Continue ticking inside the 11s window — must NOT re-fire.
    for (int i = 0; i < 60; i++) {
      clock.advance(const Duration(milliseconds: 100));
      engine.debugTick();
    }

    final woodClacks = audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;
    expect(woodClacks, 1);
  });

  test(
      'Advancing through 12 rounds produces 12 bell_start, 0 whistle_long, '
      '12 bell_end, 24 wood_clack cues (Boxing cue contract)', () {
    engine.start();

    // Finish preCountdown: fire the 11s warning then expire.
    clock.advance(const Duration(seconds: 34));
    engine.debugTick(); // fires wood_clack (45→11s)
    clock.advance(const Duration(seconds: 11));
    engine.debugTick(); // expires preCountdown → work round 1 + bell_start

    for (int round = 1; round <= 12; round++) {
      // Inside work: trigger warning cue, then expire.
      clock.advance(const Duration(seconds: 169));
      engine.debugTick(); // fires wood_clack (180→11s)
      clock.advance(const Duration(seconds: 11));
      engine.debugTick(); // expires work → bell_end + rest (or complete on R12)

      if (round < 12) {
        // Inside rest: trigger warning cue, then expire.
        clock.advance(const Duration(seconds: 49));
        engine.debugTick(); // fires wood_clack (60→11s)
        clock.advance(const Duration(seconds: 11));
        engine.debugTick(); // expires rest → work round N+1 + bell_start
      }
    }

    int count(String cue) =>
        audio.playedCues.where((c) => c == cue).length;

    expect(count(WorkoutEngine.cueBellStart), 12,
        reason: '1 from preCountdown + 11 from rest→work transitions');
    expect(count(WorkoutEngine.cueWhistleLong), 0,
        reason: 'whistle_long is Smoker-only; Boxing never fires it');
    expect(count(WorkoutEngine.cueBellEnd), 12,
        reason: 'bell_end fires at end of every work phase (incl. final)');
    expect(count(WorkoutEngine.cueWoodClack), 24,
        reason: '1 preCountdown + 12 work + 11 rest warnings');

    expect(engine.state.phase, WorkoutPhase.complete);
  });

  test('pause() then resume() preserves phaseRemaining within ±50ms', () {
    engine.start();

    clock.advance(const Duration(seconds: 10));
    engine.debugTick();
    final beforePause = engine.state.phaseRemaining;

    engine.pause();
    expect(engine.state.isPaused, isTrue);
    expect(engine.state.phaseRemaining, beforePause);

    // Simulate 5 seconds of wall-clock time elapsing while paused.
    clock.advance(const Duration(seconds: 5));

    engine.resume();
    expect(engine.state.isPaused, isFalse);

    final afterResume = engine.state.phaseRemaining;
    final delta =
        (afterResume.inMilliseconds - beforePause.inMilliseconds).abs();
    expect(delta, lessThan(50),
        reason: 'resume should restore the captured remaining time');
  });

  test('skipPhase() during work advances to rest with currentRound unchanged',
      () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work round 1

    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 1);

    engine.skipPhase();

    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.currentRound, 1);
    expect(audio.playedCues.contains(WorkoutEngine.cueBellEnd), isTrue,
        reason: 'bell_end fires on work-phase exit');
    expect(audio.playedCues.contains(WorkoutEngine.cueWhistleLong), isFalse,
        reason: 'whistle_long is Smoker-only');
  });

  test('skipPhase() during rest of round N advances to work of round N+1', () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work round 1
    clock.advance(const Duration(seconds: 180));
    engine.debugTick(); // → rest round 1

    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.currentRound, 1);

    engine.skipPhase();

    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 2);
  });

  test('endWorkout() sets phase=complete and fires bell_end', () {
    engine.start();
    engine.endWorkout();

    expect(engine.state.phase, WorkoutPhase.complete);
    expect(audio.playedCues.last, WorkoutEngine.cueBellEnd);
  });

  test('endWorkout(playCompletionCue: false) does NOT play bell_end', () {
    engine.start();
    audio.playedCues.clear(); // ignore any pre-countdown / start cues
    engine.endWorkout(playCompletionCue: false);

    expect(engine.state.phase, WorkoutPhase.complete);
    expect(
      audio.playedCues,
      isNot(contains(WorkoutEngine.cueBellEnd)),
      reason: 'User-initiated END must be silent',
    );
  });

  test('dispose() does not throw if called mid-workout', () {
    engine.start();
    clock.advance(const Duration(seconds: 30));
    engine.debugTick();

    expect(() => engine.dispose(), returnsNormally);
    // tearDown will call dispose() again — the engine must tolerate it.
  });

  // --- Boxing cue-contract tests (Step 3.2.1.1) ---

  test('Boxing: bell_end fires at end of every work phase', () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // preCountdown → work R1
    audio.playedCues.clear();

    int bellEnds() =>
        audio.playedCues.where((c) => c == WorkoutEngine.cueBellEnd).length;

    // Work R1 → rest R1: one bell_end.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();
    expect(bellEnds(), 1, reason: 'bell_end fires on work R1 exit');

    // Rest R1 → work R2: NO new bell_end (rest-exit fires bell_start only).
    clock.advance(const Duration(seconds: 60));
    engine.debugTick();
    expect(bellEnds(), 1, reason: 'rest-exit fires bell_start, not bell_end');

    // Work R2 → rest R2: another bell_end.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();
    expect(bellEnds(), 2, reason: 'bell_end fires on work R2 exit');
  });

  test('Boxing: whistle_long never fires anywhere in the workout flow', () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1

    for (int round = 1; round <= 12; round++) {
      clock.advance(const Duration(seconds: 180));
      engine.debugTick(); // work → rest (or complete on R12)
      if (round < 12) {
        clock.advance(const Duration(seconds: 60));
        engine.debugTick(); // rest → work N+1
      }
    }

    expect(
      audio.playedCues,
      isNot(contains(WorkoutEngine.cueWhistleLong)),
      reason: 'Boxing preset must never fire whistle_long (Smoker-only cue)',
    );
  });

  test('Boxing: final round skips rest, transitions directly to complete',
      () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1

    // Run rounds 1–11 (each full work + rest).
    for (int round = 1; round <= 11; round++) {
      clock.advance(const Duration(seconds: 180));
      engine.debugTick(); // work → rest
      clock.advance(const Duration(seconds: 60));
      engine.debugTick(); // rest → work N+1
    }

    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 12);

    // Expire R12 work — must go straight to complete, NOT rest.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();

    expect(engine.state.phase, WorkoutPhase.complete);
  });

  test(
      'phase duration ≤ warningThresholdMs suppresses wood_clack for that '
      'phase (boundary is strict >, so 11s is suppressed)', () {
    // Helper: builds a fresh engine with custom work/rest seconds, runs
    // through the full workout, and returns per-phase wood_clack counts
    // attributed to preCountdown / work / rest.
    Map<String, int> runAndAttribute({
      required int workSeconds,
      required int restSeconds,
      int rounds = 12,
    }) {
      final testAudio = FakeAudioService();
      final testClock = TestClock(DateTime.utc(2026, 1, 1, 12));
      final testEngine = WorkoutEngine(
        config: WorkoutConfig(
          presetId: 'test',
          totalRounds: rounds,
          workDuration: Duration(seconds: workSeconds),
          restDuration: Duration(seconds: restSeconds),
          preCountdown: const Duration(seconds: 45),
        ),
        audio: testAudio,
        clock: testClock.now,
      );

      int clacksDuringPhase(void Function() advance) {
        final before = testAudio.playedCues
            .where((c) => c == WorkoutEngine.cueWoodClack)
            .length;
        advance();
        final after = testAudio.playedCues
            .where((c) => c == WorkoutEngine.cueWoodClack)
            .length;
        return after - before;
      }

      testEngine.start();

      // preCountdown (always 45s > 11s, should fire).
      final preCount = clacksDuringPhase(() {
        testClock.advance(const Duration(seconds: 45));
        testEngine.debugTick();
      });

      int workTotal = 0;
      int restTotal = 0;
      for (int r = 1; r <= rounds; r++) {
        workTotal += clacksDuringPhase(() {
          testClock.advance(Duration(seconds: workSeconds));
          testEngine.debugTick();
        });
        if (r < rounds) {
          restTotal += clacksDuringPhase(() {
            testClock.advance(Duration(seconds: restSeconds));
            testEngine.debugTick();
          });
        }
      }

      testEngine.dispose();
      return {
        'preCountdown': preCount,
        'work': workTotal,
        'rest': restTotal,
      };
    }

    // Case a: work=10s (≤11, suppressed), rest=30s (>11, fires).
    final caseA = runAndAttribute(workSeconds: 10, restSeconds: 30);
    expect(caseA['work'], 0,
        reason: 'work=10s is too short → wood_clack suppressed on every work');
    expect(caseA['rest'], 11,
        reason: 'rest=30s fires normally on all 11 rest phases (no rest after R12)');
    expect(caseA['preCountdown'], 1, reason: 'preCountdown always fires at 45s');

    // Case b: work=180s (>11, fires), rest=10s (≤11, suppressed).
    final caseB = runAndAttribute(workSeconds: 180, restSeconds: 10);
    expect(caseB['work'], 12,
        reason: 'work=180s fires once per work phase (12 rounds)');
    expect(caseB['rest'], 0,
        reason: 'rest=10s is too short → wood_clack suppressed on every rest');
    expect(caseB['preCountdown'], 1);

    // Case c: boundary — 11s exactly. Guard is strict `>`, so 11 is NOT > 11.
    final caseC = runAndAttribute(workSeconds: 11, restSeconds: 11);
    expect(caseC['work'], 0,
        reason: 'work=11s is at the boundary → suppressed (guard is strict >)');
    expect(caseC['rest'], 0,
        reason: 'rest=11s is at the boundary → suppressed');
    expect(caseC['preCountdown'], 1);
  });

  test('Boxing: final round fires bell_end exactly once (no double bell)',
      () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1

    // Advance to start of R12.
    for (int round = 1; round <= 11; round++) {
      clock.advance(const Duration(seconds: 180));
      engine.debugTick();
      clock.advance(const Duration(seconds: 60));
      engine.debugTick();
    }
    audio.playedCues.clear(); // drop prior bell_ends (rounds 1..11)

    // Expire R12 work.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();

    expect(
      audio.playedCues.where((c) => c == WorkoutEngine.cueBellEnd).length,
      1,
      reason:
          'work-exit fires bell_end; complete-entry must NOT fire a second',
    );
    expect(engine.state.phase, WorkoutPhase.complete);
  });
}
