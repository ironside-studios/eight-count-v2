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
      'Advancing through 12 rounds produces 12 bell_start, 11 whistle_long, '
      '1 bell_end, 24 wood_clack cues', () {
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
      engine.debugTick(); // expires work; → rest (or complete on round 12)

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
    expect(count(WorkoutEngine.cueWhistleLong), 11,
        reason: 'work→rest transitions for rounds 1..11');
    expect(count(WorkoutEngine.cueBellEnd), 1,
        reason: 'final work→complete transition after round 12');
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
    expect(audio.playedCues.contains(WorkoutEngine.cueWhistleLong), isTrue);
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
}
