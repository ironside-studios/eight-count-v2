import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/smoker_config.dart';
import '../models/workout_block.dart';
import '../models/workout_block_type.dart';
import '../models/workout_config.dart';
import '../models/workout_phase.dart';
import '../models/workout_state.dart';
import '../services/audio_service.dart';

/// The workout state machine.
///
/// Architectural contract (non-negotiable, see Step 3.1 spec):
///   1. `remainingSeconds` is NEVER stored as mutable state. It is always
///      re-derived from DateTime math:
///          remaining = _phaseEndsAt.difference(_clock())
///      Ticker drives rebuilds, DateTime drives truth.
///   2. Audio cues never overlap — AudioService handles stop-before-play.
///      Engine just calls [AudioService.play].
///   3. wood_clack fires at remaining ≤ 11000ms (NOT 10000ms) so the 1.88s
///      clip finishes before bell_end / bell_start at 0ms. Boxing preset
///      fires it in work AND rest. Smoker preset fires it in Boxing-block
///      work + rest AND in transition rests; Tabata blocks suppress it
///      (their periods are too short for an 11s warning to be useful).
///      preCountdown and complete stay silent.
///   4. Phase-entry cues (bell_start, whistle_long, bell_end) fire from
///      [_advanceToPhase], NOT from the tick loop. Guarantees one fire
///      per phase regardless of tick frequency.
///
/// Multi-config support (Phase 2b):
///   The engine accepts [WorkoutConfig] (Boxing, Custom — single block)
///   or [SmokerConfig] (4 content blocks separated by 3 transitions) as
///   `Object config`. Boxing/Custom call sites are fully unchanged; the
///   Smoker dispatch is a parallel branch.
class WorkoutEngine extends ChangeNotifier {
  WorkoutEngine({
    required this.config,
    required this.audio,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    if (config is! WorkoutConfig && config is! SmokerConfig) {
      throw ArgumentError(
        'WorkoutEngine config must be WorkoutConfig or SmokerConfig, '
        'got ${config.runtimeType}',
      );
    }
  }

  final Object config;
  final AudioService audio;
  final DateTime Function() _clock;

  /// Engine public view of the injected clock (exposed for coherent tests).
  DateTime get clockNow => _clock();

  /// When the current phase began. Useful for debug overlays and
  /// coherent-time assertions in tests.
  @visibleForTesting
  DateTime? get phaseStartedAt => _phaseStartedAt;

  /// Absolute wall time at which the current phase expires. Exposed so the
  /// UI layer (Step 3.2) can bypass state-snapshot staleness if needed.
  @visibleForTesting
  DateTime? get phaseEndsAt => _phaseEndsAt;

  // --- Cue names (mirror AudioService contract) ---
  static const String cueWoodClack = 'wood_clack';
  static const String cueBellStart = 'bell_start';
  static const String cueBellEnd = 'bell_end';
  static const String cueWhistleLong = 'whistle_long';
  static const String cueWhistleDouble = 'whistle_double';

  /// Lead time before a Boxing rest period ends at which wood_clack fires.
  /// Equivalent to "remaining ≤ 11000ms" in tick math.
  static const Duration _restClackLeadTime = Duration(seconds: 11);

  // --- Owned mutable state (never exposed as setters) ---
  WorkoutPhase _phase = WorkoutPhase.preCountdown;
  int _currentRound = 0;
  DateTime? _phaseStartedAt;
  DateTime? _phaseEndsAt;
  Duration? _pausedRemaining;
  bool _isPaused = false;
  bool _isStarted = false;
  bool _disposed = false;
  final Set<String> _firedCuesThisPeriod = <String>{};

  /// Debug-only: when true, [_playCue] no-ops to suppress audio dispatch
  /// during the multi-phase chain inside [debugSkipForward]. Always false
  /// in release (the only setter is gated by [kDebugMode]).
  bool _suppressCuesUntilNextTick = false;

  // --- Smoker-only state (null for WorkoutConfig configs) ---
  List<WorkoutBlock>? _blocks;
  int? _blockIdx;
  WorkoutBlockType? _currentBlockType;

  /// Round index within the current content block (1..N). For transitions
  /// this is held at 1 (the transition's single rest period).
  int _roundInCurrentBlock = 0;

  Ticker? _ticker;

  // --- Config helpers (branch on type) ---

  String get _presetId =>
      config is WorkoutConfig ? (config as WorkoutConfig).presetId : (config as SmokerConfig).presetId;

  Duration get _preCountdown => config is WorkoutConfig
      ? (config as WorkoutConfig).preCountdown
      : (config as SmokerConfig).preCountdown;

  int get _totalRounds => config is WorkoutConfig
      ? (config as WorkoutConfig).totalRounds
      : (config as SmokerConfig).totalRounds;

  bool get _isSmoker => config is SmokerConfig;

  // --- Public read-only state snapshot ---
  WorkoutState get state {
    final phaseDuration = _currentPhaseDuration();
    Duration remaining;

    if (_phase == WorkoutPhase.complete) {
      remaining = Duration.zero;
    } else if (_isPaused && _pausedRemaining != null) {
      remaining = _pausedRemaining!;
    } else if (_phaseEndsAt != null) {
      final diff = _phaseEndsAt!.difference(_clock());
      remaining = diff.isNegative ? Duration.zero : diff;
    } else {
      // Pre-start: report the full phase duration so UIs that mount before
      // start() see a sensible "about to begin" snapshot.
      remaining = phaseDuration;
    }

    return WorkoutState(
      phase: _phase,
      currentRound: _currentRound,
      totalRounds: _totalRounds,
      phaseRemaining: remaining,
      phaseDuration: phaseDuration,
      isPaused: _isPaused,
      currentBlockIndex: _userFacingBlockIndex(),
      blockType: _currentBlockType,
    );
  }

  // --- Public API ---

  /// Begins the workout at the preCountdown phase.
  void start() {
    if (_isStarted || _disposed) return;
    _isStarted = true;
    _phase = WorkoutPhase.preCountdown;
    _currentRound = 0;
    _isPaused = false;
    _pausedRemaining = null;
    _firedCuesThisPeriod.clear();

    if (_isSmoker) {
      final smoker = config as SmokerConfig;
      _blocks = List<WorkoutBlock>.unmodifiable(smoker.blocks);
      _blockIdx = 0;
      _currentBlockType = _blocks![0].blockType;
      _roundInCurrentBlock = 1;
    }

    final now = _clock();
    _phaseStartedAt = now;
    _phaseEndsAt = now.add(_preCountdown);
    _ticker = Ticker(_onTick)..start();
    notifyListeners();
  }

  /// Captures the current remaining time and halts the ticker.
  /// No-op if the engine is already paused, not started, or complete.
  void pause() {
    if (!_isStarted || _isPaused || _phase == WorkoutPhase.complete) return;
    if (_phaseEndsAt == null) return;
    final diff = _phaseEndsAt!.difference(_clock());
    _pausedRemaining = diff.isNegative ? Duration.zero : diff;
    _isPaused = true;
    _ticker?.stop();
    notifyListeners();
  }

  /// Recomputes [phaseEndsAt] from the paused remaining and restarts the ticker.
  void resume() {
    if (!_isStarted || !_isPaused || _phase == WorkoutPhase.complete) return;
    if (_pausedRemaining == null) return;
    final now = _clock();
    _phaseEndsAt = now.add(_pausedRemaining!);
    _phaseStartedAt = now.subtract(_currentPhaseDuration() - _pausedRemaining!);
    _pausedRemaining = null;
    _isPaused = false;
    _ticker?.start();
    notifyListeners();
  }

  /// DEV-ONLY: force-advance past the current phase.
  void skipPhase() {
    if (!_isStarted || _phase == WorkoutPhase.complete) return;
    _advanceFromCurrentPhase();
    notifyListeners();
  }

  /// DEBUG ONLY: Advances the workout clock forward by [seconds] seconds.
  /// Tree-shaken from release builds (kDebugMode is `const false` in
  /// release; the early return becomes dead code Dart's tree-shaker
  /// strips). Used for fast-forwarding through phases to test audio
  /// cues at boundaries without sitting through full phase durations.
  ///
  /// Implementation: shifts the current phase's [_phaseStartedAt] and
  /// [_phaseEndsAt] anchors backward by [seconds] so the derived
  /// remainingMs (always computed from `_phaseEndsAt.difference(_clock())`,
  /// never stored) jumps forward without any state mutation. Preserves
  /// the engine's derived-state invariant.
  ///
  /// If the shift takes the current phase past expiry (remainingMs ≤ 0),
  /// chains [_advanceFromCurrentPhase] calls until landing in a
  /// non-expired phase or [WorkoutPhase.complete]. Cue dispatch is
  /// suppressed for the duration of the chain via
  /// [_suppressCuesUntilNextTick] so multi-phase skips don't trigger a
  /// barrage of bell/whistle sounds.
  void debugSkipForward(int seconds) {
    if (!kDebugMode) return;
    if (seconds <= 0) return;
    if (!_isStarted) return;
    if (_phase == WorkoutPhase.complete) return;
    if (_phaseStartedAt == null || _phaseEndsAt == null) return;

    final shift = Duration(seconds: seconds);
    _phaseStartedAt = _phaseStartedAt!.subtract(shift);
    _phaseEndsAt = _phaseEndsAt!.subtract(shift);

    _suppressCuesUntilNextTick = true;
    while (_phase != WorkoutPhase.complete &&
        _phaseEndsAt!.difference(_clock()).inMilliseconds <= 0) {
      _advanceFromCurrentPhase();
    }
    _suppressCuesUntilNextTick = false;

    // Mark the wood_clack as "already fired" for the new period if the
    // skip landed inside its lead-time window — otherwise the next
    // _pollState would dispatch a clack as if the warning hadn't yet
    // played (it would have, naturally, if the user had ridden the
    // phase normally instead of skipping). This keeps cue idempotency
    // honest across skips.
    final remainingAfter =
        _phaseEndsAt!.difference(_clock()).inMilliseconds;
    if (_isWoodClackEligiblePeriod() &&
        remainingAfter <=
            _woodClackLeadTimeForCurrentPhase().inMilliseconds) {
      _firedCuesThisPeriod.add(cueWoodClack);
    }

    notifyListeners();
  }

  /// Short-circuit the workout to complete.
  ///
  /// By default fires bell_end — natural completion (final work round expiry,
  /// which also routes through the complete phase) keeps the triumphant
  /// ending cue.
  ///
  /// Pass `playCompletionCue: false` when the user abandons the workout
  /// (STOP → END dialog). Abandoning is not a completion; the bell would
  /// feel celebratory and wrong.
  void endWorkout({bool playCompletionCue = true}) {
    if (_disposed || _phase == WorkoutPhase.complete) return;
    _advanceToPhase(
      WorkoutPhase.complete,
      playCompletionCue: playCompletionCue,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _ticker?.dispose();
    _ticker = null;
    _firedCuesThisPeriod.clear();
    super.dispose();
  }

  /// Exposed so tests can drive the state machine deterministically against
  /// an injected clock, without waiting for real frame callbacks.
  @visibleForTesting
  void debugTick() => _pollState();

  // --- Internals ---

  /// Routes audio.play() through this helper so [debugSkipForward] can
  /// suppress cue dispatch during a multi-phase fast-forward without
  /// emitting a barrage of bells/whistles. Release builds are unaffected
  /// — [_suppressCuesUntilNextTick] only flips to true inside
  /// [debugSkipForward], which itself short-circuits if [kDebugMode] is
  /// false. Net effect: in release, this is a thin pass-through to
  /// audio.play and the suppression check tree-shakes away.
  void _playCue(String cue) {
    if (kDebugMode && _suppressCuesUntilNextTick) return;
    audio.play(cue);
  }

  Duration _currentPhaseDuration() {
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        return _preCountdown;
      case WorkoutPhase.work:
        if (_isSmoker) return _blocks![_blockIdx!].workDuration;
        return (config as WorkoutConfig).workDuration;
      case WorkoutPhase.rest:
        if (_isSmoker) return _blocks![_blockIdx!].restDuration;
        return (config as WorkoutConfig).restDuration;
      case WorkoutPhase.complete:
        return Duration.zero;
    }
  }

  /// 1-indexed user-facing CONTENT block number (1..4 for V2 Smoker).
  /// Returns null for non-Smoker configs. During a transition this is the
  /// most-recently-completed content block.
  int? _userFacingBlockIndex() {
    if (!_isSmoker || _blockIdx == null || _blocks == null) return null;
    int count = 0;
    for (int i = 0; i <= _blockIdx!; i++) {
      if (_blocks![i].blockType != WorkoutBlockType.transition) count++;
    }
    return count == 0 ? null : count;
  }

  /// True iff the current period is one in which wood_clack should fire
  /// as the period approaches its end.
  ///   - preCountdown:   ALL presets (fires at 12s remaining)
  ///   - Boxing preset:  work or rest (fires at 11s remaining)
  ///   - Smoker preset:  Boxing-block work or rest, OR transition rest (11s)
  ///   - Tabata blocks:  never (periods too short for an 11s warning)
  ///   - Any work block ≤ 12s: never (warning would fire essentially at
  ///     work-start, which is meaningless). Rest, GET READY, and
  ///     transitions are NOT affected by this short-work guard.
  bool _isWoodClackEligiblePeriod() {
    if (_phase == WorkoutPhase.preCountdown) {
      return true;
    }
    if (_phase != WorkoutPhase.work && _phase != WorkoutPhase.rest) {
      return false;
    }
    // Suppress 10s-out warning on work phases ≤ 12 seconds (block too short
    // to warn). Applies to Boxing/Custom/Smoker uniformly. Rest, GET READY,
    // and transitions are NOT affected.
    if (_phase == WorkoutPhase.work &&
        _currentPhaseDuration().inSeconds <= 12) {
      return false;
    }
    if (_isSmoker) {
      switch (_currentBlockType!) {
        case WorkoutBlockType.boxing:
          return true;
        case WorkoutBlockType.tabata:
          // Tabata identity rule: NO clack in Tabata work blocks ever
          // (locked 4/28/26). This branch runs FIRST relative to any
          // duration-based suppression — Tabata gets no warning regardless
          // of work-period length, including hypothetical longer Tabatas.
          return false;
        case WorkoutBlockType.transition:
          return _phase == WorkoutPhase.rest;
      }
    }
    return _presetId == 'boxing';
  }

  /// Lead time before the current phase ends at which wood_clack fires.
  /// Boxing preset uses 12s for ALL phases (preCountdown, work, rest).
  /// Custom and Smoker presets keep the legacy 11s contract for work/rest
  /// (preCountdown still uses 12s for them via the eligibility gate).
  Duration _woodClackLeadTimeForCurrentPhase() {
    if (_phase == WorkoutPhase.preCountdown) {
      return const Duration(seconds: 12);
    }
    // Work or rest: Boxing preset gets the longer 12s warning.
    if (!_isSmoker && _presetId == 'boxing') {
      return const Duration(seconds: 12);
    }
    return _restClackLeadTime;
  }

  /// Returns the cue that should fire 1s before the current phase ends,
  /// or null if no early bell is desired for this phase.
  ///
  ///   - preCountdown ends → bell_start (work begins next, all presets)
  ///       except Smoker entering a Tabata block, which uses whistle_long
  ///       on phase entry — silent on the preCountdown side here so we
  ///       don't double-cue.
  ///   - work ends:
  ///       * non-final round → bell_end (rest follows)
  ///       * final round (last round of last block in Smoker, or last
  ///         round of Boxing/Custom) → bell_end (workout completes)
  ///       Smoker Tabata work ends silently (whistle_long on rest entry
  ///       handles the cue).
  ///   - rest ends → null (rest-end is signaled by the next work's
  ///     bell_start, which we fire 1s before THIS rest ends — covered
  ///     by the work-entry cue path on the next phase, NOT here).
  ///   - complete: never reached (engine stopped).
  String? _earlyBellCueForPhaseEnd() {
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        // Fire bell_start 1s before preCountdown ends. For Smoker first
        // block of type Tabata, return null — the on-boundary
        // whistle_long fired from _advanceToPhase work-Tabata branch
        // handles work-entry cuing for Tabata (no early shift).
        if (_isSmoker) {
          final firstBlock = _blocks!.first;
          switch (firstBlock.blockType) {
            case WorkoutBlockType.boxing:
              return cueBellStart;
            case WorkoutBlockType.tabata:
              return null;
            case WorkoutBlockType.transition:
              return null;
          }
        }
        return cueBellStart;

      case WorkoutPhase.work:
        if (_isSmoker) {
          switch (_currentBlockType!) {
            case WorkoutBlockType.boxing:
              return cueBellEnd;
            case WorkoutBlockType.tabata:
              // R1..R{N-1}: stay silent at the 1s-early gate —
              // whistle_double fires AT remainingMs ≤ 0 from
              // _advanceFromCurrentPhaseSmoker, on-boundary by design.
              // R{N} (last round of the Tabata block): fire bell_end
              // 1s early, matching the Boxing option-b shift so the
              // gong lands ON the work→rest (or work→complete)
              // boundary instead of starting fresh after it.
              if (_blocks != null && _blockIdx != null) {
                final tabataBlock = _blocks![_blockIdx!];
                if (_roundInCurrentBlock >= tabataBlock.totalRounds) {
                  return cueBellEnd;
                }
              }
              return null;
            case WorkoutBlockType.transition:
              return null;
          }
        }
        return cueBellEnd;

      case WorkoutPhase.rest:
        // The NEXT phase's bell_start (or block-equivalent) is fired
        // pre-emptively as that phase's preCountdown-equivalent shift.
        // But there's no preCountdown before "work after rest" — work
        // starts immediately. So fire bell_start 1s before rest ends.
        if (_isSmoker) {
          // Determine what the next phase will be.
          final blocks = _blocks!;
          final currentBlock = blocks[_blockIdx!];
          final isLastRoundOfBlock =
              _roundInCurrentBlock >= currentBlock.totalRounds;
          if (currentBlock.blockType == WorkoutBlockType.transition) {
            // Transition rest ends → next content block's first work.
            // Boxing-next: fire bell_start 1s early (option-b shift).
            // Tabata-next: return null — whistle_long fires on-boundary
            // from _advanceToPhase, not 1s early.
            final nextBlock = blocks[_blockIdx! + 1];
            switch (nextBlock.blockType) {
              case WorkoutBlockType.boxing:
                return cueBellStart;
              case WorkoutBlockType.tabata:
                return null;
              case WorkoutBlockType.transition:
                return null;
            }
          }
          if (isLastRoundOfBlock) {
            // Intra-block rest after the last work round? In current
            // engine architecture, last round of a block transitions
            // directly from work → next block (no rest). So this branch
            // is unreachable, but defensively return null.
            return null;
          }
          // Standard intra-block rest → next work in same block. Boxing
          // gets bell_start 1s early (option-b). Tabata returns null —
          // whistle_long fires on-boundary from _advanceToPhase.
          switch (currentBlock.blockType) {
            case WorkoutBlockType.boxing:
              return cueBellStart;
            case WorkoutBlockType.tabata:
              return null;
            case WorkoutBlockType.transition:
              return null;
          }
        }
        // Boxing / Custom: rest → next work, fire bell_start.
        return cueBellStart;

      case WorkoutPhase.complete:
        return null;
    }
  }

  void _onTick(Duration _) => _pollState();

  void _pollState() {
    if (_disposed || _isPaused) return;
    if (_phase == WorkoutPhase.complete) return;
    if (_phaseEndsAt == null) return;

    final remainingMs = _phaseEndsAt!.difference(_clock()).inMilliseconds;

    if (_isWoodClackEligiblePeriod() &&
        remainingMs <= _woodClackLeadTimeForCurrentPhase().inMilliseconds &&
        !_firedCuesThisPeriod.contains(cueWoodClack)) {
      _firedCuesThisPeriod.add(cueWoodClack);
      _playCue(cueWoodClack);
    }

    // Fire phase-end / phase-entry bells 1 second early so the display
    // reads the full duration of the new phase instead of sitting on "0"
    // for a beat. The phase boundary itself is unchanged at remainingMs=0;
    // only the audio cue is shifted forward.
    //
    // Per-cue keys ensure each bell fires at most once per phase, in line
    // with the existing wood_clack contract.
    //
    // Note: Tabata cues (whistle_long at work-start, whistle_double at
    // round-end, bell_end at block-end) are intentionally on-boundary,
    // not 1s-early — see _earlyBellCueForPhaseEnd, which returns null
    // for all Tabata-work-entry paths. This block continues to fire
    // bell_start / bell_end / wood_clack for Boxing and the bell on
    // transition→Boxing-block work-entry.
    if (remainingMs <= 1000 && remainingMs > 0) {
      final cueKey = _earlyBellCueForPhaseEnd();
      if (cueKey != null && !_firedCuesThisPeriod.contains(cueKey)) {
        _firedCuesThisPeriod.add(cueKey);
        _playCue(cueKey);
      }
    }

    if (remainingMs <= 0) {
      _advanceFromCurrentPhase();
    }

    notifyListeners();
  }

  void _advanceFromCurrentPhase() {
    if (_isSmoker) {
      _advanceFromCurrentPhaseSmoker();
      return;
    }

    // --- WorkoutConfig (Boxing / Custom) — preserved exactly as before ---
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        _advanceToPhase(WorkoutPhase.work, round: 1);
        break;
      case WorkoutPhase.work:
        // Boxing cue contract: bell_end fires at the end of every work
        // phase — both non-final (work → rest) and final (work → complete).
        // We fire it HERE on the work-exit side so user-initiated END
        // (which routes through endWorkout → _advanceToPhase(complete, …))
        // stays silent.
        // audio.play(cueBellEnd); // SUPPRESSED: fired 1s early by _pollState (option-b shift)
        if (_currentRound < (config as WorkoutConfig).totalRounds) {
          _advanceToPhase(WorkoutPhase.rest);
        } else {
          // Final round: skip the rest phase entirely. bell_end has already
          // fired above, so suppress the complete-entry cue to avoid a
          // double bell.
          _advanceToPhase(
            WorkoutPhase.complete,
            playCompletionCue: false,
          );
        }
        break;
      case WorkoutPhase.rest:
        _advanceToPhase(WorkoutPhase.work, round: _currentRound + 1);
        break;
      case WorkoutPhase.complete:
        break;
    }
  }

  void _advanceFromCurrentPhaseSmoker() {
    final blocks = _blocks!;
    switch (_phase) {
      case WorkoutPhase.preCountdown:
        // First content block of Smoker is always blockIdx=0 (V2: Boxing).
        _advanceToPhase(WorkoutPhase.work, round: 1);
        break;

      case WorkoutPhase.work:
        // Work-exit cue per block type.
        // Compute "last round of block" once — needed both for the
        // work-exit Tabata cue selection (whistle_double vs bell_end) and
        // for the phase-advance branching below.
        final tabataExitBlock = blocks[_blockIdx!];
        final tabataExitIsLastRoundOfBlock =
            _roundInCurrentBlock >= tabataExitBlock.totalRounds;

        switch (_currentBlockType!) {
          case WorkoutBlockType.boxing:
            // audio.play(cueBellEnd); // SUPPRESSED: fired 1s early by _pollState (option-b shift)
            break;
          case WorkoutBlockType.tabata:
            // Tabata work-exit cue:
            //   R1..R{N-1} → whistle_double (round-end signal), AT
            //     remainingMs ≤ 0 — on-boundary, intentionally not
            //     shifted (the triple-whistle reads as a beat marker
            //     and lands cleanest on the rest-entry tick).
            //   R{N} (last round of the block) → bell_end is fired by
            //     the 1s-early option-b shift in _pollState (see
            //     _earlyBellCueForPhaseEnd's Tabata work branch). NO
            //     fire HERE on the late path — would be a duplicate
            //     (the cue is already in _firedCuesThisPeriod) and
            //     muddies the on-boundary intent.
            if (!tabataExitIsLastRoundOfBlock) {
              _playCue(cueWhistleDouble);
            }
            break;
          case WorkoutBlockType.transition:
            // Transitions have no work phase; unreachable.
            break;
        }

        final isLastRoundOfBlock = tabataExitIsLastRoundOfBlock;

        if (!isLastRoundOfBlock) {
          // Intra-block: next is rest. Round counter advances on rest-exit.
          _advanceToPhase(WorkoutPhase.rest);
        } else if (_blockIdx! + 1 < blocks.length) {
          // Last round of a non-final block → enter the trailing transition.
          _blockIdx = _blockIdx! + 1;
          _currentBlockType = blocks[_blockIdx!].blockType;
          _roundInCurrentBlock = 1; // transition is its own single period
          _advanceToPhase(WorkoutPhase.rest);
        } else {
          // Last round of the LAST block → complete.
          // Both Boxing-last-block (bell_end fired via 1s-early shift) AND
          // Tabata-last-block (bell_end fired above on the work-exit Tabata
          // branch) have ALREADY fired bell_end by this point. Suppress
          // complete-entry to avoid a double bell.
          _advanceToPhase(
            WorkoutPhase.complete,
            playCompletionCue: false,
          );
        }
        break;

      case WorkoutPhase.rest:
        if (_currentBlockType == WorkoutBlockType.transition) {
          // Transition's single rest period is over — advance to the next
          // (content) block's first work round.
          _blockIdx = _blockIdx! + 1;
          _currentBlockType = blocks[_blockIdx!].blockType;
          _roundInCurrentBlock = 1;
          _advanceToPhase(WorkoutPhase.work, round: _currentRound + 1);
        } else {
          // Intra-block rest → next round's work in the same block.
          _roundInCurrentBlock++;
          _advanceToPhase(WorkoutPhase.work, round: _currentRound + 1);
        }
        break;

      case WorkoutPhase.complete:
        break;
    }
  }

  void _advanceToPhase(
    WorkoutPhase newPhase, {
    int? round,
    bool playCompletionCue = true,
  }) {
    _phase = newPhase;
    if (round != null) _currentRound = round;
    _firedCuesThisPeriod.clear();

    final now = _clock();
    _phaseStartedAt = now;
    final duration = _currentPhaseDuration();
    _phaseEndsAt = duration == Duration.zero ? now : now.add(duration);

    switch (newPhase) {
      case WorkoutPhase.work:
        if (_isSmoker) {
          switch (_currentBlockType!) {
            case WorkoutBlockType.boxing:
              // audio.play(cueBellStart); // SUPPRESSED: fired 1s early by _pollState (option-b shift)
              break;
            case WorkoutBlockType.tabata:
              // Tabata work-start cue (2026-04-29): whistle_long fires
              // AT phase entry (full work duration remaining), NOT 1s
              // early via _pollState. Tabata cues are intentionally
              // on-boundary so they read as "round started" rather than
              // "round about to start".
              _playCue(cueWhistleLong);
              break;
            case WorkoutBlockType.transition:
              // Transitions have no work phase; unreachable.
              break;
          }
        } else {
          // audio.play(cueBellStart); // SUPPRESSED: fired 1s early by _pollState (option-b shift)
        }
        break;
      case WorkoutPhase.rest:
        // Non-Smoker (Boxing): rest-entry is SILENT. whistle_long is
        // reserved for the Smoker preset — the asset stays preloaded by
        // AudioService but nothing fires it on Boxing.
        if (_isSmoker && _currentBlockType == WorkoutBlockType.tabata) {
          // V2 COMPROMISE: whistle_double.mp3 has not been recorded yet.
          // For V2.0 we fire a single whistle_long on Tabata rest-start.
          // V2.1 task: record whistle_double, swap cue name here.
          // audio.play(cueWhistleLong); // SUPPRESSED: fired 1s early by _pollState (option-b shift)
        }
        // Boxing-block rest and transition rest are silent on entry.
        break;
      case WorkoutPhase.complete:
        // [playCompletionCue] is false on two paths:
        //   (1) user-initiated END (engine.endWorkout(playCompletionCue: false))
        //   (2) natural final-round completion when work-exit already fired
        //       bell_end (Boxing path; or Smoker last-block-is-Boxing).
        if (playCompletionCue) {
          _playCue(cueBellEnd);
        }
        _ticker?.stop();
        break;
      case WorkoutPhase.preCountdown:
        break;
    }
  }
}
