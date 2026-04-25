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

class TestClock {
  TestClock(this._now);

  DateTime _now;
  DateTime now() => _now;
  void advance(Duration d) {
    _now = _now.add(d);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService audio;
  late TestClock clock;
  late WorkoutEngine engine;

  setUp(() {
    audio = FakeAudioService();
    clock = TestClock(DateTime.utc(2026, 4, 25, 12));
    engine = WorkoutEngine(
      config: WorkoutConfig.boxing(),
      audio: audio,
      clock: clock.now,
    );
  });

  tearDown(() {
    engine.dispose();
  });

  /// Fast-forwards a freshly started Boxing engine to the start of round 1
  /// rest (preCountdown 45s → work R1 180s).
  void advanceToRestR1() {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1
    clock.advance(const Duration(seconds: 180));
    engine.debugTick(); // → rest R1
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.currentRound, 1);
    audio.playedCues.clear();
  }

  // --- Rest-period clack tests ---

  test('wood_clack fires once when elapsed_in_rest reaches 49s', () {
    advanceToRestR1();

    int clacks() => audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;

    // elapsed = 48s → still 12s remaining, no fire.
    clock.advance(const Duration(seconds: 48));
    engine.debugTick();
    expect(clacks(), 0, reason: 'too early — 12s remaining');

    // elapsed = 49s → 11s remaining, must fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'crossed 11s threshold');

    // elapsed = 50s → still inside the window, must NOT re-fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'idempotent within the same period');
  });

  test('wood_clack fires once per rest period across multiple rounds', () {
    engine.start();

    int clackCount() => audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;

    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();

    // R1 work runs to expiry (will fire its own work-side clack on the way).
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.rest);
    final beforeR1Rest = clackCount();

    // R1 rest: cross 49s — must fire exactly one new clack.
    clock.advance(const Duration(seconds: 49));
    engine.debugTick();
    expect(clackCount() - beforeR1Rest, 1,
        reason: 'R1 rest fires exactly one wood_clack');

    // Expire R1 rest, then run R2 work to expiry.
    clock.advance(const Duration(seconds: 11));
    engine.debugTick(); // → work R2
    clock.advance(const Duration(seconds: 180));
    engine.debugTick(); // → rest R2
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.currentRound, 2);
    final beforeR2Rest = clackCount();

    // R2 rest: cross 49s — must fire exactly one new clack.
    clock.advance(const Duration(seconds: 49));
    engine.debugTick();
    expect(clackCount() - beforeR2Rest, 1,
        reason: 'R2 rest fires exactly one wood_clack; '
            'fired-set resets on every period transition');
  });

  // --- Pre-workout countdown safety test ---

  test('wood_clack does NOT fire during pre-workout countdown', () {
    engine.start();
    expect(engine.state.phase, WorkoutPhase.preCountdown);

    // Advance through the entire 45s preCountdown in 1s ticks, including
    // across the would-be 11s threshold (elapsed = 34s). Stop just before
    // crossing into work R1.
    for (int i = 0; i < 44; i++) {
      clock.advance(const Duration(seconds: 1));
      engine.debugTick();
      expect(engine.state.phase, WorkoutPhase.preCountdown,
          reason: 'must stay in preCountdown for the duration of the test');
    }

    expect(
      audio.playedCues,
      isNot(contains(WorkoutEngine.cueWoodClack)),
      reason: 'pre-workout countdown must remain silent at the 11s mark',
    );
  });

  // --- Work-period clack tests (extended Phase 2a) ---

  test(
      'wood_clack fires once when elapsed_in_work reaches 169s '
      '(11s remaining)', () {
    engine.start();
    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playedCues.clear();

    int clacks() => audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;

    // elapsed = 168s → still 12s remaining, no fire.
    clock.advance(const Duration(seconds: 168));
    engine.debugTick();
    expect(clacks(), 0, reason: 'too early — 12s remaining in work');

    // elapsed = 169s → 11s remaining, must fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'crossed 11s threshold in work');

    // elapsed = 170s → still inside the window, must NOT re-fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'idempotent within the same work period');
  });

  test(
      'wood_clack fires in every work period across full 12-round Boxing flow '
      '(12 work + 11 rest = 23 total)', () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1

    for (int round = 1; round <= 12; round++) {
      // Inside work: cross the 11s threshold then expire.
      clock.advance(const Duration(seconds: 169));
      engine.debugTick(); // fires work-side wood_clack
      clock.advance(const Duration(seconds: 11));
      engine.debugTick(); // expires work → rest (or complete on R12)

      if (round < 12) {
        // Inside rest: cross the 11s threshold then expire.
        clock.advance(const Duration(seconds: 49));
        engine.debugTick(); // fires rest-side wood_clack
        clock.advance(const Duration(seconds: 11));
        engine.debugTick(); // expires rest → work N+1
      }
    }

    final clacks = audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;
    expect(clacks, 23,
        reason: '12 work periods + 11 rest periods (no rest after R12)');
    expect(engine.state.phase, WorkoutPhase.complete);
  });
}
