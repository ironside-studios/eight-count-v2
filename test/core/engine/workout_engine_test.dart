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

  test(
      'wood_clack fires exactly once when crossing the 11s threshold inside '
      'a Boxing rest period (and not before)', () {
    engine.start();

    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    // work R1 → rest R1 (180s work).
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();

    expect(engine.state.phase, WorkoutPhase.rest);
    audio.playedCues.clear();

    // Inside rest: cross the 11s boundary at 49s elapsed.
    clock.advance(const Duration(seconds: 49));
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
      '12 bell_end, 23 wood_clack cues (Boxing cue contract)', () {
    engine.start();

    // Finish preCountdown — no wood_clack fires here under Phase 2a scope.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // expires preCountdown → work round 1 + bell_start

    for (int round = 1; round <= 12; round++) {
      // Inside work: cross the 11s threshold then expire.
      clock.advance(const Duration(seconds: 169));
      engine.debugTick(); // fires work-side wood_clack
      clock.advance(const Duration(seconds: 11));
      engine.debugTick(); // expires work → bell_end + rest (or complete on R12)

      if (round < 12) {
        // Inside rest: cross the 11s threshold then expire.
        clock.advance(const Duration(seconds: 49));
        engine.debugTick(); // fires rest-side wood_clack
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
    expect(count(WorkoutEngine.cueWoodClack), 23,
        reason: '12 work-side + 11 rest-side (no rest after R12)');

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
