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

    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();

    // R1 work → R1 rest.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.rest);

    // R1 rest: cross 49s, then expire.
    clock.advance(const Duration(seconds: 49));
    engine.debugTick(); // wood_clack #1
    clock.advance(const Duration(seconds: 11));
    engine.debugTick(); // → work R2

    // R2 work → R2 rest.
    clock.advance(const Duration(seconds: 180));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.currentRound, 2);

    // R2 rest: cross 49s.
    clock.advance(const Duration(seconds: 49));
    engine.debugTick(); // wood_clack #2

    final clacks = audio.playedCues
        .where((c) => c == WorkoutEngine.cueWoodClack)
        .length;
    expect(clacks, 2, reason: 'one per rest period; fired-set resets on transition');
  });

  test('wood_clack does not fire during Boxing work period', () {
    engine.start();

    // preCountdown → work R1.
    clock.advance(const Duration(seconds: 45));
    engine.debugTick();
    expect(engine.state.phase, WorkoutPhase.work);
    audio.playedCues.clear();

    // Inside work: advance to elapsed = 169s (would be 11s remaining if it
    // were rest), tick repeatedly across the would-be threshold.
    clock.advance(const Duration(seconds: 169));
    engine.debugTick();
    for (int i = 0; i < 30; i++) {
      clock.advance(const Duration(milliseconds: 200));
      engine.debugTick();
    }

    expect(
      audio.playedCues,
      isNot(contains(WorkoutEngine.cueWoodClack)),
      reason: 'wood_clack is Boxing-rest only — work period must be silent',
    );
  });
}
