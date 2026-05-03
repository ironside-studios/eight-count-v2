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

  test('wood_clack fires once when elapsed_in_rest reaches 48s '
      '(12s remaining under Boxing 12s lead, commit ace1634)', () {
    advanceToRestR1();

    int clacks() => audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;

    // elapsed = 47s → still 13s remaining, no fire (gate is ≤12s for
    // Boxing preset, see workout_engine.dart _woodClackLeadTimeForCurrentPhase).
    clock.advance(const Duration(seconds: 47));
    engine.debugTick();
    expect(clacks(), 0, reason: 'too early — 13s remaining');

    // elapsed = 48s → 12s remaining, must fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'crossed 12s threshold (Boxing rest lead)');

    // elapsed = 49s → still inside the window, must NOT re-fire.
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

  test('wood_clack fires exactly once during pre-workout countdown at '
      '12s remaining (commit 2975b5c — GET READY clack)', () {
    engine.start();
    expect(engine.state.phase, WorkoutPhase.preCountdown);

    // Tick across the 12s threshold (elapsed = 33s, remain = 12s). Stop
    // just before crossing into work R1.
    for (int i = 0; i < 44; i++) {
      clock.advance(const Duration(seconds: 1));
      engine.debugTick();
      expect(engine.state.phase, WorkoutPhase.preCountdown,
          reason: 'must stay in preCountdown for the duration of the test');
    }

    final clacks = audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;
    expect(clacks, 1,
        reason: 'preCountdown clack fires exactly once when remain ≤ 12s; '
            '_firedCuesThisPeriod set prevents re-fire on subsequent ticks');
  });

  // --- Work-period clack tests (extended Phase 2a) ---

  test(
      'wood_clack fires once when elapsed_in_work reaches 168s '
      '(12s remaining under Boxing 12s lead, commit ace1634)', () {
    engine.start();
    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playedCues.clear();

    int clacks() => audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;

    // elapsed = 167s → still 13s remaining, no fire (Boxing 12s lead).
    clock.advance(const Duration(seconds: 167));
    engine.debugTick();
    expect(clacks(), 0, reason: 'too early — 13s remaining in work');

    // elapsed = 168s → 12s remaining, must fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'crossed 12s threshold in work');

    // elapsed = 169s → still inside the window, must NOT re-fire.
    clock.advance(const Duration(seconds: 1));
    engine.debugTick();
    expect(clacks(), 1, reason: 'idempotent within the same work period');
  });

  test(
      'wood_clack fires in every work period across full 12-round Boxing flow '
      '(1 preCountdown + 12 work + 11 rest = 24 total)', () {
    engine.start();
    clock.advance(const Duration(seconds: 45));
    engine.debugTick(); // → work R1 (preCountdown clack already fired
    // on this same tick — gate samples remain ≤ 12s as the engine walks
    // toward 0; commit 2975b5c added preCountdown clack).

    for (int round = 1; round <= 12; round++) {
      // Inside work: cross the 12s threshold (Boxing 12s lead, commit
      // ace1634) then expire.
      clock.advance(const Duration(seconds: 169));
      engine.debugTick(); // fires work-side wood_clack
      clock.advance(const Duration(seconds: 11));
      engine.debugTick(); // expires work → rest (or complete on R12)

      if (round < 12) {
        // Inside rest: cross the 12s threshold then expire.
        clock.advance(const Duration(seconds: 49));
        engine.debugTick(); // fires rest-side wood_clack
        clock.advance(const Duration(seconds: 11));
        engine.debugTick(); // expires rest → work N+1
      }
    }

    final clacks = audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;
    expect(clacks, 24,
        reason: '1 preCountdown + 12 work + 11 rest = 24 '
            '(no rest after R12; commit 2975b5c adds preCountdown clack)');
    expect(engine.state.phase, WorkoutPhase.complete);
  });
}
