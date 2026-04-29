import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAudioService audio;
  late TestClock clock;
  late WorkoutEngine engine;

  setUp(() {
    audio = FakeAudioService();
    clock = TestClock(DateTime.utc(2026, 4, 25, 12));
    engine = WorkoutEngine(
      config: SmokerConfig.standard(),
      audio: audio,
      clock: clock.now,
    );
  });

  tearDown(() {
    engine.dispose();
  });

  /// Drive the engine forward by `d`, then tick once. Returns nothing —
  /// inspect the engine / audio log directly.
  void advanceAndTick(Duration d) {
    clock.advance(d);
    engine.debugTick();
  }

  /// Fast-forward through a Boxing-block round that is NOT the last round
  /// of its block: 180s work (with wood_clack at 11s remaining + bell_end
  /// at expiry) → 60s rest (with wood_clack + transition).
  void runBoxingFullRound() {
    advanceAndTick(const Duration(seconds: 180)); // → rest
    advanceAndTick(const Duration(seconds: 60)); // → next work
  }

  /// Fast-forward through a Boxing block's LAST round (no intra-block rest;
  /// transitions to the trailing transition rest phase).
  void runBoxingLastRoundWork() {
    advanceAndTick(const Duration(seconds: 180));
  }

  /// Fast-forward through a Tabata round that is NOT the last round of its
  /// block: 20s work → 10s rest → next work.
  void runTabataFullRound() {
    advanceAndTick(const Duration(seconds: 20));
    advanceAndTick(const Duration(seconds: 10));
  }

  /// Fast-forward through a Tabata block's LAST round (no intra-block rest).
  void runTabataLastRoundWork() {
    advanceAndTick(const Duration(seconds: 20));
  }

  /// Fast-forward through the 60s transition rest, expiring it onto the
  /// next block's first work entry.
  void completeTransition() {
    advanceAndTick(const Duration(seconds: 60));
  }

  /// Run preCountdown to expiry, landing on Block 1 round 1 work-entry.
  void runPreCountdownToBlock1() {
    engine.start();
    advanceAndTick(const Duration(seconds: 45));
    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.blockType, WorkoutBlockType.boxing);
    expect(engine.state.currentBlockIndex, 1);
  }

  // --------------------------------------------------------------------
  // 1. SmokerConfig.standard() structure
  // --------------------------------------------------------------------

  test('SmokerConfig.standard(): 4 content blocks + 3 transitions, '
      'expected parameters', () {
    final cfg = SmokerConfig.standard();
    expect(cfg.presetId, 'smoker');
    expect(cfg.preCountdown, const Duration(seconds: 45));
    expect(cfg.totalRounds, 28, reason: '6 + 8 + 6 + 8 (transitions excluded)');
    expect(cfg.blocks.length, 7);

    // B1 — Boxing
    expect(cfg.blocks[0].blockType, WorkoutBlockType.boxing);
    expect(cfg.blocks[0].totalRounds, 6);
    expect(cfg.blocks[0].workDuration, const Duration(seconds: 180));
    expect(cfg.blocks[0].restDuration, const Duration(seconds: 60));

    // T
    expect(cfg.blocks[1].blockType, WorkoutBlockType.transition);
    expect(cfg.blocks[1].restDuration, const Duration(seconds: 60));

    // B2 — Tabata
    expect(cfg.blocks[2].blockType, WorkoutBlockType.tabata);
    expect(cfg.blocks[2].totalRounds, 8);
    expect(cfg.blocks[2].workDuration, const Duration(seconds: 20));
    expect(cfg.blocks[2].restDuration, const Duration(seconds: 10));

    // T
    expect(cfg.blocks[3].blockType, WorkoutBlockType.transition);

    // B3 — Boxing
    expect(cfg.blocks[4].blockType, WorkoutBlockType.boxing);
    expect(cfg.blocks[4].totalRounds, 6);

    // T
    expect(cfg.blocks[5].blockType, WorkoutBlockType.transition);

    // B4 — Tabata
    expect(cfg.blocks[6].blockType, WorkoutBlockType.tabata);
    expect(cfg.blocks[6].totalRounds, 8);
  });

  // --------------------------------------------------------------------
  // 2. Engine.start() with SmokerConfig
  // --------------------------------------------------------------------

  test('start() with SmokerConfig: phase=preCountdown, blockType=boxing, '
      'currentBlockIndex=1, totalRounds=28', () {
    engine.start();
    final s = engine.state;
    expect(s.phase, WorkoutPhase.preCountdown);
    expect(s.blockType, WorkoutBlockType.boxing,
        reason: 'first content block is Boxing');
    expect(s.currentBlockIndex, 1);
    expect(s.totalRounds, 28);
    expect(s.currentRound, 0);
    expect(s.phaseDuration, const Duration(seconds: 45));
    expect(audio.playLog, isEmpty,
        reason: 'no cues fire during preCountdown entry');
  });

  // --------------------------------------------------------------------
  // 3. Block 1 round 1 cue contract
  // --------------------------------------------------------------------

  test('Block 1 R1 (Boxing): bell_start on work-entry, wood_clack at 11s '
      'in work, bell_end on work-end, silent rest-entry, wood_clack at '
      '11s in rest', () {
    runPreCountdownToBlock1();
    expect(audio.playLog, contains(WorkoutEngine.cueBellStart),
        reason: 'work-entry fires bell_start');
    expect(_count(audio.playLog, WorkoutEngine.cueBellStart), 1);

    // Cross 11s threshold inside work (elapsed=169s).
    advanceAndTick(const Duration(seconds: 169));
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 1,
        reason: 'work-side wood_clack fires at 11s remaining');

    // Expire work — fires bell_end and advances to rest.
    advanceAndTick(const Duration(seconds: 11));
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd), 1,
        reason: 'work-exit fires bell_end on Boxing block');

    // Rest-entry must be silent — no whistle_long appears between the
    // bell_end and the next wood_clack.
    final preRestLogLen = audio.playLog.length;
    expect(audio.playLog.last, WorkoutEngine.cueBellEnd,
        reason: 'rest-entry is silent on Boxing block');

    // Cross 11s threshold inside rest (elapsed=49s).
    advanceAndTick(const Duration(seconds: 49));
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 2,
        reason: 'rest-side wood_clack fires at 11s remaining');
    expect(audio.playLog.length, preRestLogLen + 1,
        reason: 'only the wood_clack was added during the rest period so far');
  });

  // --------------------------------------------------------------------
  // 4. Block 1 → Transition (after R6 work-end)
  // --------------------------------------------------------------------

  test('Block 1 R6 work-end → Transition: bell_end fires, transition rest '
      'starts (blockType=transition), wood_clack at 11s remaining', () {
    runPreCountdownToBlock1();

    // Run rounds 1..5 (full round = work + rest).
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.currentRound, 6);
    final beforeR6Exit = audio.playLog.length;

    // Round 6 work expires → bell_end + advance to transition rest.
    advanceAndTick(const Duration(seconds: 180));
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.blockType, WorkoutBlockType.transition);

    // Verify bell_end was the cue fired on work-exit.
    final exitCues = audio.playLog.sublist(beforeR6Exit);
    expect(exitCues, contains(WorkoutEngine.cueBellEnd));

    // Cross 11s threshold inside transition (elapsed=49s).
    final preClack = _count(audio.playLog, WorkoutEngine.cueWoodClack);
    advanceAndTick(const Duration(seconds: 49));
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), preClack + 1,
        reason: 'transition rest fires wood_clack at 11s remaining');
  });

  // --------------------------------------------------------------------
  // 5. Transition → Block 2 (Tabata)
  // --------------------------------------------------------------------

  test('Transition → Block 2 (Tabata) R1: whistle_long on work-entry '
      '(NOT bell_start), no wood_clack during 20s work', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork(); // → transition rest
    expect(engine.state.blockType, WorkoutBlockType.transition);

    // Capture log baseline before transition expires + Block 2 entry.
    final beforeTransitionEnd = audio.playLog.length;

    // Transition rest expires → Block 2 R1 work-entry.
    completeTransition();
    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.blockType, WorkoutBlockType.tabata);
    expect(engine.state.currentBlockIndex, 2);
    expect(engine.state.currentRound, 7,
        reason: 'global rounds: B1 had 6, B2 R1 is round 7');

    final entryCues = audio.playLog.sublist(beforeTransitionEnd);
    expect(entryCues, contains(WorkoutEngine.cueWhistleLong),
        reason: 'Tabata work-entry fires whistle_long');
    expect(entryCues, isNot(contains(WorkoutEngine.cueBellStart)),
        reason: 'Tabata work-entry does NOT fire bell_start');

    // Run the entire 20s work; no wood_clack should fire.
    final preClack = _count(audio.playLog, WorkoutEngine.cueWoodClack);
    advanceAndTick(const Duration(seconds: 20));
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), preClack,
        reason: 'Tabata work suppresses wood_clack regardless of remaining');
  });

  // --------------------------------------------------------------------
  // 6. & 7. Block 2 R1 work-end (silent) + rest-entry (whistle_long, no clack)
  // --------------------------------------------------------------------

  test('Block 2 R1 work-end: SILENT (no bell_end), then rest-entry fires '
      'whistle_long, no wood_clack during 10s rest', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition();

    expect(engine.state.phase, WorkoutPhase.work);
    expect(engine.state.blockType, WorkoutBlockType.tabata);
    final whistlesBeforeWorkExit =
        _count(audio.playLog, WorkoutEngine.cueWhistleLong);
    final bellEndsBeforeWorkExit =
        _count(audio.playLog, WorkoutEngine.cueBellEnd);

    // Expire 20s work → must NOT fire bell_end. Then rest-entry fires
    // whistle_long.
    advanceAndTick(const Duration(seconds: 20));
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd),
        bellEndsBeforeWorkExit,
        reason: 'Tabata work-exit is silent — no bell_end');
    expect(
      _count(audio.playLog, WorkoutEngine.cueWhistleLong) -
          whistlesBeforeWorkExit,
      1,
      reason: 'rest-entry fires whistle_long (V2 single-whistle compromise)',
    );

    // Run the entire 10s rest; no wood_clack should fire.
    final preClack = _count(audio.playLog, WorkoutEngine.cueWoodClack);
    advanceAndTick(const Duration(seconds: 10));
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), preClack,
        reason: 'Tabata rest suppresses wood_clack regardless of remaining');
  });

  // --------------------------------------------------------------------
  // 8. Block 2 → Transition → Block 3
  // --------------------------------------------------------------------

  test('Block 2 → Transition → Block 3: blockIdx chain, '
      'currentBlockIndex 2 → 3, blockType returns to boxing', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B2 R1 work

    // Run B2 rounds 1..7 then R8 (last) work.
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    expect(engine.state.blockType, WorkoutBlockType.tabata);
    expect(engine.state.currentRound, 14,
        reason: 'B1 had 6 + B2 R8 is global round 14');

    runTabataLastRoundWork(); // → transition before B3
    expect(engine.state.blockType, WorkoutBlockType.transition);
    expect(engine.state.currentBlockIndex, 2,
        reason: 'currentBlockIndex tracks the most-recent CONTENT block');

    completeTransition(); // → B3 R1 work
    expect(engine.state.blockType, WorkoutBlockType.boxing);
    expect(engine.state.currentBlockIndex, 3);
    expect(engine.state.currentRound, 15);
  });

  // --------------------------------------------------------------------
  // 9. Block 3 fires Boxing cues identically to Block 1 (delta-counted)
  // --------------------------------------------------------------------

  test('Block 3 fires identical Boxing cue counts to Block 1 (symmetric '
      'delta comparison)', () {
    runPreCountdownToBlock1();
    // R1 work-entry just fired bell_start; baseline excludes it so the
    // delta covers the *remaining* cues of Block 1 (R2..R6 work-entries,
    // R1..R6 work-exits, all clacks, transition's clack).
    final b1Base = {
      'bellStart': _count(audio.playLog, WorkoutEngine.cueBellStart),
      'bellEnd': _count(audio.playLog, WorkoutEngine.cueBellEnd),
      'clack': _count(audio.playLog, WorkoutEngine.cueWoodClack),
      'whistle': _count(audio.playLog, WorkoutEngine.cueWhistleLong),
    };

    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B2 R1 work-entry (fires Tabata whistle_long)

    final b1Delta = {
      'bellStart':
          _count(audio.playLog, WorkoutEngine.cueBellStart) - b1Base['bellStart']!,
      'bellEnd':
          _count(audio.playLog, WorkoutEngine.cueBellEnd) - b1Base['bellEnd']!,
      'clack': _count(audio.playLog, WorkoutEngine.cueWoodClack) - b1Base['clack']!,
      'whistle':
          _count(audio.playLog, WorkoutEngine.cueWhistleLong) - b1Base['whistle']!,
    };

    // Concrete sanity on Block 1 numbers.
    expect(b1Delta['bellStart'], 5,
        reason: 'R2..R6 work-entries (R1 fired before baseline)');
    expect(b1Delta['bellEnd'], 6, reason: 'R1..R6 work-exits fire bell_end');
    expect(b1Delta['clack'], 12,
        reason: '6 work + 5 rest + 1 transition wood_clacks');
    // The transition into B2 fires whistle_long for Tabata work-entry.
    expect(b1Delta['whistle'], 1,
        reason: 'B2 R1 work-entry whistle_long (transition just expired)');

    // Run all of Block 2 + its trailing transition.
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    runTabataLastRoundWork();
    completeTransition(); // → B3 R1 work-entry (fires Boxing bell_start)

    final b3Base = {
      'bellStart': _count(audio.playLog, WorkoutEngine.cueBellStart),
      'bellEnd': _count(audio.playLog, WorkoutEngine.cueBellEnd),
      'clack': _count(audio.playLog, WorkoutEngine.cueWoodClack),
      'whistle': _count(audio.playLog, WorkoutEngine.cueWhistleLong),
    };

    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B4 R1 work-entry (fires Tabata whistle_long)

    final b3Delta = {
      'bellStart':
          _count(audio.playLog, WorkoutEngine.cueBellStart) - b3Base['bellStart']!,
      'bellEnd':
          _count(audio.playLog, WorkoutEngine.cueBellEnd) - b3Base['bellEnd']!,
      'clack': _count(audio.playLog, WorkoutEngine.cueWoodClack) - b3Base['clack']!,
      'whistle':
          _count(audio.playLog, WorkoutEngine.cueWhistleLong) - b3Base['whistle']!,
    };

    expect(b3Delta, equals(b1Delta),
        reason: 'Block 3 must fire the same cue pattern as Block 1');
  });

  // --------------------------------------------------------------------
  // 10. Block 4 R8 → complete (bell_end fires 1s-early via option-b
  //     shift; complete-entry is silent)
  // --------------------------------------------------------------------

  test('Block 4 R8 work-end → complete: bell_end fires 1s-early during '
      'final second of work (NOT on complete-entry); no rest after final '
      'round', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition();
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    runTabataLastRoundWork(); // → T2
    completeTransition(); // → B3
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork(); // → T3
    completeTransition(); // → B4 R1
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    expect(engine.state.blockType, WorkoutBlockType.tabata);
    expect(engine.state.currentBlockIndex, 4);
    expect(engine.state.currentRound, 28);
    expect(engine.state.phase, WorkoutPhase.work);

    final bellEndsBefore = _count(audio.playLog, WorkoutEngine.cueBellEnd);
    final whistlesBefore =
        _count(audio.playLog, WorkoutEngine.cueWhistleLong);

    // Drive R8 work to its 1s-early gate window: 19s tick lands at
    // remainingMs=1000, fires bell_end via option-b shift.
    advanceAndTick(const Duration(seconds: 19));
    expect(engine.state.phase, WorkoutPhase.work,
        reason: 'still in R8 work after 19s; phase advances at 20s');
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd) - bellEndsBefore,
        1,
        reason: 'R8 (last round) fires bell_end 1s-early via option-b '
            'shift, in WORK phase (not on complete-entry)');

    // Final 1s tick → remainingMs=0 → phase advances to complete.
    // Complete-entry must NOT fire a second bell_end (playCompletionCue:
    // false is set in the Smoker last-block path).
    advanceAndTick(const Duration(seconds: 1));
    expect(engine.state.phase, WorkoutPhase.complete);
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd) - bellEndsBefore,
        1,
        reason: 'no double-bell — complete-entry stays silent because '
            'bell_end already fired 1s-early during work');
    expect(
      _count(audio.playLog, WorkoutEngine.cueWhistleLong) - whistlesBefore,
      0,
      reason: 'no rest after final round, so no rest-entry whistle_long',
    );
  });

  // --------------------------------------------------------------------
  // 11. Total cue counts for full Smoker flow
  // --------------------------------------------------------------------

  test('Full Smoker flow cue totals: 12 bell_start, 13 bell_end, '
      '30 whistle_long, 25 wood_clack', () {
    runPreCountdownToBlock1();

    // Block 1
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B2

    // Block 2
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    runTabataLastRoundWork();
    completeTransition(); // → B3

    // Block 3
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B4

    // Block 4
    for (int i = 0; i < 7; i++) {
      runTabataFullRound();
    }
    runTabataLastRoundWork(); // → complete

    expect(engine.state.phase, WorkoutPhase.complete);
    expect(_count(audio.playLog, WorkoutEngine.cueBellStart), 12,
        reason: '6 B1 + 6 B3 work-entries');
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd), 13,
        reason: '6 B1 + 6 B3 work-exits + 1 complete-entry');
    expect(_count(audio.playLog, WorkoutEngine.cueWhistleLong), 30,
        reason: '8 work-entries × 2 Tabata blocks (16) + '
            '7 rest-entries × 2 Tabata blocks (14) = 30');
    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack), 25,
        reason: '(6 work + 5 rest) × 2 Boxing blocks = 22, '
            '+ 3 transitions = 25');
  });

  // --------------------------------------------------------------------
  // 12. Idempotency: 50 ticks during one rest period → 1 wood_clack
  // --------------------------------------------------------------------

  test('Idempotency: 50 ticks across the 11s window inside a single '
      'Boxing-block rest fires wood_clack exactly once', () {
    runPreCountdownToBlock1();
    advanceAndTick(const Duration(seconds: 180)); // → R1 rest
    expect(engine.state.phase, WorkoutPhase.rest);
    expect(engine.state.blockType, WorkoutBlockType.boxing);

    final preClack = _count(audio.playLog, WorkoutEngine.cueWoodClack);

    // Cross the 11s threshold and tick 50 times across ~5 seconds.
    advanceAndTick(const Duration(seconds: 49));
    for (int i = 0; i < 50; i++) {
      advanceAndTick(const Duration(milliseconds: 100));
    }

    expect(_count(audio.playLog, WorkoutEngine.cueWoodClack) - preClack, 1,
        reason: 'idempotent within the same period');
  });

  // --------------------------------------------------------------------
  // 13. Pause/resume during Tabata work survives, no duplicate cues
  // --------------------------------------------------------------------

  test('Pause/resume during Tabata work: state survives, no duplicate cues '
      'on resume', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B2 R1 work
    expect(engine.state.blockType, WorkoutBlockType.tabata);

    // 5s into Tabata work.
    advanceAndTick(const Duration(seconds: 5));
    final beforePauseRemaining = engine.state.phaseRemaining;
    final cueLogBeforePause = List<String>.from(audio.playLog);

    engine.pause();
    expect(engine.state.isPaused, isTrue);
    expect(audio.playLog, equals(cueLogBeforePause),
        reason: 'pause must not fire any cue');

    // 5s of wall time elapses while paused.
    clock.advance(const Duration(seconds: 5));

    engine.resume();
    expect(engine.state.isPaused, isFalse);
    expect(audio.playLog, equals(cueLogBeforePause),
        reason: 'resume must not fire a duplicate work-entry cue');

    final afterResumeRemaining = engine.state.phaseRemaining;
    final delta = (afterResumeRemaining.inMilliseconds -
            beforePauseRemaining.inMilliseconds)
        .abs();
    expect(delta, lessThan(50),
        reason: 'remaining preserved within ±50ms across pause/resume');
  });

  // --------------------------------------------------------------------
  // 14. endWorkout(playCompletionCue: false) during Block 2 R3
  // --------------------------------------------------------------------

  test('endWorkout(playCompletionCue: false) during Block 2 R3 advances '
      'to complete WITHOUT firing bell_end', () {
    runPreCountdownToBlock1();
    for (int i = 0; i < 5; i++) {
      runBoxingFullRound();
    }
    runBoxingLastRoundWork();
    completeTransition(); // → B2 R1 work

    // Run B2 R1 (full) and B2 R2 (full); now at B2 R3 work-entry.
    runTabataFullRound();
    runTabataFullRound();
    expect(engine.state.blockType, WorkoutBlockType.tabata);
    expect(engine.state.currentRound, 9, reason: 'B1=6 + B2 R3 = round 9');

    // Mid-work in R3, user abandons.
    advanceAndTick(const Duration(seconds: 8));
    expect(engine.state.phase, WorkoutPhase.work);

    final bellEndsBefore = _count(audio.playLog, WorkoutEngine.cueBellEnd);

    engine.endWorkout(playCompletionCue: false);
    expect(engine.state.phase, WorkoutPhase.complete);
    expect(_count(audio.playLog, WorkoutEngine.cueBellEnd), bellEndsBefore,
        reason: 'user-abandon must not fire bell_end');
  });

  // --------------------------------------------------------------------
  // 15. Boxing config (NON-Smoker) regression sanity test
  // --------------------------------------------------------------------

  test('Regression: Boxing config (non-Smoker) runs 3 rounds with the same '
      'cue contract as before Phase 2b', () {
    final boxingAudio = FakeAudioService();
    final boxingClock = TestClock(DateTime.utc(2026, 4, 25, 12));
    final boxingEngine = WorkoutEngine(
      config: WorkoutConfig.custom(rounds: 3, workSeconds: 180, restSeconds: 60),
      audio: boxingAudio,
      clock: boxingClock.now,
    );
    addTearDown(boxingEngine.dispose);

    boxingEngine.start();
    expect(boxingEngine.state.blockType, isNull,
        reason: 'non-Smoker configs leave blockType null');
    expect(boxingEngine.state.currentBlockIndex, isNull,
        reason: 'non-Smoker configs leave currentBlockIndex null');

    // preCountdown → R1.
    boxingClock.advance(const Duration(seconds: 45));
    boxingEngine.debugTick();

    // R1 work + rest, R2 work + rest, R3 work → complete.
    boxingClock.advance(const Duration(seconds: 180));
    boxingEngine.debugTick();
    boxingClock.advance(const Duration(seconds: 60));
    boxingEngine.debugTick();
    boxingClock.advance(const Duration(seconds: 180));
    boxingEngine.debugTick();
    boxingClock.advance(const Duration(seconds: 60));
    boxingEngine.debugTick();
    boxingClock.advance(const Duration(seconds: 180));
    boxingEngine.debugTick();

    expect(boxingEngine.state.phase, WorkoutPhase.complete);

    // Note: WorkoutConfig.custom uses presetId='custom', not 'boxing', so
    // wood_clack is suppressed for Custom (Phase 2a scope).
    expect(_count(boxingAudio.playLog, WorkoutEngine.cueBellStart), 3,
        reason: '3 work-entries fire bell_start');
    expect(_count(boxingAudio.playLog, WorkoutEngine.cueBellEnd), 3,
        reason: '3 work-exits fire bell_end (R3 suppresses complete-entry)');
    expect(_count(boxingAudio.playLog, WorkoutEngine.cueWhistleLong), 0);
    expect(_count(boxingAudio.playLog, WorkoutEngine.cueWoodClack), 0,
        reason: 'Custom preset suppresses wood_clack (Phase 2a scope)');
  });
}
