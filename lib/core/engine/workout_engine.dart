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
  /// at the 11s-remaining mark.
  ///   - Boxing preset:  work or rest
  ///   - Smoker preset:  Boxing-block work or rest, OR a transition rest
  ///   - Tabata blocks:  never (periods too short for an 11s warning)
  ///   - preCountdown:   never
  bool _isWoodClackEligiblePeriod() {
    if (_phase != WorkoutPhase.work && _phase != WorkoutPhase.rest) {
      return false;
    }
    if (_isSmoker) {
      switch (_currentBlockType!) {
        case WorkoutBlockType.boxing:
          return true;
        case WorkoutBlockType.tabata:
          return false;
        case WorkoutBlockType.transition:
          return _phase == WorkoutPhase.rest;
      }
    }
    // Boxing / Custom single-block configs.
    return _presetId == 'boxing';
  }

  void _onTick(Duration _) => _pollState();

  void _pollState() {
    if (_disposed || _isPaused) return;
    if (_phase == WorkoutPhase.complete) return;
    if (_phaseEndsAt == null) return;

    final remainingMs = _phaseEndsAt!.difference(_clock()).inMilliseconds;

    if (_isWoodClackEligiblePeriod() &&
        remainingMs <= _restClackLeadTime.inMilliseconds &&
        !_firedCuesThisPeriod.contains(cueWoodClack)) {
      _firedCuesThisPeriod.add(cueWoodClack);
      audio.play(cueWoodClack);
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
        audio.play(cueBellEnd);
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
        switch (_currentBlockType!) {
          case WorkoutBlockType.boxing:
            audio.play(cueBellEnd);
            break;
          case WorkoutBlockType.tabata:
            // Silent — next phase entry handles cue continuity.
            break;
          case WorkoutBlockType.transition:
            // Transitions have no work phase; unreachable.
            break;
        }

        final currentBlock = blocks[_blockIdx!];
        final isLastRoundOfBlock =
            _roundInCurrentBlock >= currentBlock.totalRounds;

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
          // If the last block is Boxing, bell_end already fired on work-exit
          // above; suppress complete-entry to avoid a double bell. If the
          // last block is Tabata, work-exit was silent — fire bell_end on
          // complete-entry so the workout ends with the triumphant cue.
          final lastBlockWasBoxing =
              _currentBlockType == WorkoutBlockType.boxing;
          _advanceToPhase(
            WorkoutPhase.complete,
            playCompletionCue: !lastBlockWasBoxing,
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
              audio.play(cueBellStart);
              break;
            case WorkoutBlockType.tabata:
              audio.play(cueWhistleLong);
              break;
            case WorkoutBlockType.transition:
              // Transitions have no work phase; unreachable.
              break;
          }
        } else {
          audio.play(cueBellStart);
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
          audio.play(cueWhistleLong);
        }
        // Boxing-block rest and transition rest are silent on entry.
        break;
      case WorkoutPhase.complete:
        // [playCompletionCue] is false on two paths:
        //   (1) user-initiated END (engine.endWorkout(playCompletionCue: false))
        //   (2) natural final-round completion when work-exit already fired
        //       bell_end (Boxing path; or Smoker last-block-is-Boxing).
        if (playCompletionCue) {
          audio.play(cueBellEnd);
        }
        _ticker?.stop();
        break;
      case WorkoutPhase.preCountdown:
        break;
    }
  }
}
