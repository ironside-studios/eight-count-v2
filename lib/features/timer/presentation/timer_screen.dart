import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show debugPrint, kDebugMode, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'package:eight_count/core/design/phase_colors.dart';
import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/smoker_config.dart';
import 'package:eight_count/core/models/workout_block_type.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/services/audio_service.dart';
import 'package:eight_count/core/utils/time_format.dart';
import 'package:eight_count/features/timer/presentation/widgets/block_label.dart';
import 'package:eight_count/generated/l10n/app_localizations.dart';
import 'package:eight_count/main.dart' show audioService;

/// Real-time workout timer screen — renders pre-countdown, work, and rest
/// phases for the Boxing preset.
///
/// Flow:
///   1. Screen mounts, engine is constructed (boxing preset) but NOT started.
///   2. Full gold ring + static "45" digit + "TAP TO START" hint.
///   3. User taps anywhere → engine.start() begins the 45s countdown.
///      Phase label "GET READY" appears above the ring, PAUSE/STOP controls
///      replace the hint, the ring drains, and the digit updates per frame.
///   4. Engine advances preCountdown → work R1 → rest R1 → work R2 → … →
///      work R12 → complete. Phase label and round card swap per phase;
///      digit + ring derive from engine.state on every frame.
///   5. PAUSE freezes everything and dims the screen; RESUME unfreezes.
///   6. STOP opens a confirmation dialog; END silently (no bell) pops home.
///   7. Natural completion (final work round expires) fires bell_end via
///      the engine and triggers [_onEngineChange] to pop home.
///
/// Cues (all fired by the engine, not the UI) — Boxing contract:
///   - wood_clack at 11s remaining in every non-complete phase
///   - bell_start on work-phase entry (incl. from preCountdown and rest)
///   - bell_end on work-phase EXIT (every round, including final)
///   - rest-entry is SILENT (whistle_long is reserved for Smoker)

/// Smoker variant of the "remaining total seconds" calculation. Walks
/// `config.blocks` once to resolve the engine's current LINEAR position
/// (a unique index into the block list), then sums every prior block's
/// full duration plus the partial contribution of the current period.
///
/// Why a linear-position resolve: engine state exposes
/// `(blockType, currentBlockIndex)`, where `currentBlockIndex` tracks the
/// most-recently-completed CONTENT block per Stage 1's contract. During
/// a transition, `currentBlockIndex` matches the content block before
/// the transition — meaning the tuple alone can't distinguish "inside
/// content block N" from "inside transition AFTER content block N"
/// without consulting the phase. Resolving to a single integer linearIdx
/// upfront eliminates that ambiguity for the rest of the loop.
///
/// `total` here INCLUDES the preCountdown so the displayed value during
/// preCountdown reflects "full workout duration" (e.g., 57:25 for V2
/// standard Smoker = 45 warmup + 3400 content/transitions). PreCountdown
/// elapsed never counts against the displayed remaining: as soon as
/// content begins, the value drops by the work/rest seconds consumed.
@visibleForTesting
int remainingTotalSecondsSmoker(
  SmokerConfig config,
  WorkoutPhase phase,
  int currentRound,
  int phaseRemainingMs, {
  required int? currentBlockIndex,
  required WorkoutBlockType? blockType,
}) {
  final int totalMs =
      (config.totalDurationSeconds + config.preCountdown.inSeconds) * 1000;

  if (phase == WorkoutPhase.preCountdown) {
    return (totalMs / 1000).ceil();
  }
  if (phase == WorkoutPhase.complete) {
    return 0;
  }
  if (currentBlockIndex == null || blockType == null) {
    return (totalMs / 1000).ceil();
  }

  // Resolve the engine's current linear index in config.blocks.
  int contentSeen = 0;
  int currentLinearIdx = -1;
  for (int i = 0; i < config.blocks.length; i++) {
    final WorkoutBlockType bt = config.blocks[i].blockType;
    if (bt == WorkoutBlockType.transition) {
      // Transition AFTER the content block #contentSeen.
      if (blockType == WorkoutBlockType.transition &&
          contentSeen == currentBlockIndex) {
        currentLinearIdx = i;
        break;
      }
    } else {
      contentSeen++;
      if (blockType != WorkoutBlockType.transition &&
          contentSeen == currentBlockIndex) {
        currentLinearIdx = i;
        break;
      }
    }
  }
  if (currentLinearIdx < 0) {
    // Engine state didn't match any block — safe fallback.
    return (totalMs / 1000).ceil();
  }

  int elapsedMs = 0;
  int globalRoundsConsumed = 0;
  for (int i = 0; i < currentLinearIdx; i++) {
    final b = config.blocks[i];
    if (b.blockType == WorkoutBlockType.transition) {
      elapsedMs += b.restDuration.inMilliseconds;
    } else {
      elapsedMs += b.workDuration.inMilliseconds * b.totalRounds;
      elapsedMs += b.restDuration.inMilliseconds * (b.totalRounds - 1);
      globalRoundsConsumed += b.totalRounds;
    }
  }

  // Partial contribution of the current block.
  final current = config.blocks[currentLinearIdx];
  if (current.blockType == WorkoutBlockType.transition) {
    elapsedMs += current.restDuration.inMilliseconds - phaseRemainingMs;
  } else {
    final int roundInBlock =
        (currentRound - globalRoundsConsumed).clamp(1, current.totalRounds);
    final int priorRoundsInBlock = roundInBlock - 1;
    elapsedMs += priorRoundsInBlock * current.workDuration.inMilliseconds +
        priorRoundsInBlock * current.restDuration.inMilliseconds;
    if (phase == WorkoutPhase.work) {
      elapsedMs += current.workDuration.inMilliseconds - phaseRemainingMs;
    } else {
      elapsedMs += current.workDuration.inMilliseconds +
          (current.restDuration.inMilliseconds - phaseRemainingMs);
    }
  }

  final int remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
  return (remainingMs / 1000).ceil();
}

class TimerScreen extends StatefulWidget {
  const TimerScreen({
    super.key,
    required this.presetId,
    this.overrideConfig,
  });

  final String presetId;

  /// Optional preset override. When non-null, this config drives the engine
  /// directly — used by the Custom-preset route (Step 5.2) and any future
  /// caller that wants to bypass the presetId-keyed factory dispatch.
  /// Accepts [WorkoutConfig] or [SmokerConfig]; the engine validates at
  /// runtime.
  final Object? overrideConfig;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  WorkoutEngine? _engine;
  bool _started = false;
  bool _popped = false;
  bool _completedNaturally = false;

  @override
  void initState() {
    super.initState();
    // Keep the screen awake during a workout. Sleeping mid-round = broken
    // timer + missed cues. Failure is swallowed via catchError so wakelock
    // can never crash the flow.
    unawaited(_safeWakelock(enable: true));
    Object? config;
    if (widget.overrideConfig != null) {
      // Custom-preset route (and any future caller) passes a fully-built
      // config directly. Takes precedence over the presetId-keyed factory.
      config = widget.overrideConfig;
    } else if (widget.presetId == 'boxing') {
      config = WorkoutConfig.boxing();
    } else if (widget.presetId == 'smoker') {
      config = SmokerConfig.standard();
    }
    if (config != null) {
      _engine = WorkoutEngine(config: config, audio: audioService);
      _engine!.addListener(_onEngineChange);
    } else {
      // Unrecognized preset → bounce home rather than render an empty timer.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_popped) {
          _popped = true;
          context.pop();
        }
      });
    }
  }

  void _onEngineChange() {
    if (_popped) return;
    final engine = _engine;
    if (engine == null) return;
    // Natural completion → route to the complete screen (stack replacement).
    // Intermediate transitions (preCountdown → work, work ↔ rest) stay on
    // this screen; AnimatedBuilder rebuilds handle the label / ring-color
    // / round-card swaps.
    // Wait for the engine to reach WorkoutPhase.complete naturally, then
    // hold for 5 seconds on the ":00" screen with the red ring before
    // routing. This gives the user a deliberate visual closure for the
    // final round:
    //   0:02 → 0:01 → BELL FIRES → 0:00 (held 5s, red ring) → /complete
    //
    // The bell started 1s before engine-complete (1s-early shift), so by
    // the time engine reaches complete the bell has been playing ~1s with
    // ~1.6s of clip remaining. The bell finishes well within the 5s hold;
    // the remaining ~3.4s is intentional silence holding the red ring on
    // screen. _completedNaturally tells dispose() to skip stopAll() so
    // the bell finishes cleanly across the route change.
    if (!_popped && engine.state.phase == WorkoutPhase.complete) {
      _popped = true;
      _completedNaturally = true;
      final int totalSeconds = _totalWorkoutSeconds(engine.config);
      final String presetId = widget.presetId;
      Future.delayed(const Duration(milliseconds: 5000), () {
        if (!mounted) return;
        context.go(
          '/complete',
          extra: <String, dynamic>{
            'totalSeconds': totalSeconds,
            'presetId': presetId,
          },
        );
      });
    }
    // No setState — AnimatedBuilder in build() handles rebuilds.
  }

  /// Full work + rest seconds for the configured workout (no pre-countdown).
  /// Boxing: 180*12 + 60*11 = 2820s = 47:00. Rest count is `totalRounds - 1`
  /// because the final round has no rest (work R12 → complete directly).
  /// Smoker: sums every block's work + (rounds-1)×rest plus each transition.
  static int _totalWorkoutSeconds(Object config) {
    if (config is SmokerConfig) {
      return config.totalDurationSeconds;
    }
    if (config is WorkoutConfig) {
      final int workSec = config.workDuration.inSeconds * config.totalRounds;
      final int restSec =
          config.restDuration.inSeconds * (config.totalRounds - 1);
      return workSec + restSec;
    }
    throw ArgumentError('Unknown config type: ${config.runtimeType}');
  }

  /// Remaining seconds on the whole work+rest cycle (pre-countdown excluded),
  /// derived from live engine state — never stored. Ceil'd so the last second
  /// stays on screen through its full tick.
  ///
  /// Boxing/Custom (single block):
  ///   totalMs       = workMs * N   +  restMs * (N - 1)
  ///   elapsed[work] = (round-1) * (workMs + restMs) + (workMs - phaseRemainingMs)
  ///   elapsed[rest] = (round-1) * (workMs + restMs) + workMs + (restMs - phaseRemainingMs)
  ///
  /// Smoker: walks each block's contribution, summing whole completed blocks
  /// and partially-completed periods up to the current point.
  static int _remainingTotalSeconds(
    Object config,
    WorkoutPhase phase,
    int currentRound,
    int phaseRemainingMs, {
    int? currentBlockIndex,
    WorkoutBlockType? blockType,
  }) {
    if (config is SmokerConfig) {
      return remainingTotalSecondsSmoker(
        config,
        phase,
        currentRound,
        phaseRemainingMs,
        currentBlockIndex: currentBlockIndex,
        blockType: blockType,
      );
    }
    if (config is! WorkoutConfig) {
      throw ArgumentError('Unknown config type: ${config.runtimeType}');
    }
    final int workMs = config.workDuration.inMilliseconds;
    final int restMs = config.restDuration.inMilliseconds;
    final int roundMs = workMs + restMs;
    final int totalMs =
        workMs * config.totalRounds + restMs * (config.totalRounds - 1);
    final int priorFullRounds =
        (currentRound - 1).clamp(0, config.totalRounds);

    int elapsedMs;
    switch (phase) {
      case WorkoutPhase.preCountdown:
        elapsedMs = 0;
        break;
      case WorkoutPhase.work:
        elapsedMs = priorFullRounds * roundMs + (workMs - phaseRemainingMs);
        break;
      case WorkoutPhase.rest:
        elapsedMs =
            priorFullRounds * roundMs + workMs + (restMs - phaseRemainingMs);
        break;
      case WorkoutPhase.complete:
        elapsedMs = totalMs;
        break;
    }
    final int remainingMs = (totalMs - elapsedMs).clamp(0, totalMs);
    return (remainingMs / 1000).ceil();
  }

  /// Block-local round info for the round counter card. For Boxing/Custom,
  /// returns the engine's global round directly. For Smoker, subtracts prior
  /// blocks' rounds so the user sees "ROUND 3 OF 8" within Block 2 (Tabata).
  /// Returns null when no round card should be displayed (preCountdown,
  /// complete, transition).
  static ({int current, int total})? _roundForCounter({
    required Object config,
    required WorkoutPhase phase,
    required int currentRound,
    required int? currentBlockIndex,
    required WorkoutBlockType? blockType,
  }) {
    if (phase != WorkoutPhase.work && phase != WorkoutPhase.rest) {
      return null;
    }
    if (config is SmokerConfig) {
      if (blockType == WorkoutBlockType.transition) return null;
      int roundInBlock = currentRound;
      int totalInBlock = 0;
      for (final b in config.blocks) {
        if (b.blockType == WorkoutBlockType.transition) continue;
        if (roundInBlock <= b.totalRounds) {
          totalInBlock = b.totalRounds;
          break;
        }
        roundInBlock -= b.totalRounds;
      }
      if (totalInBlock == 0) return null;
      return (current: roundInBlock, total: totalInBlock);
    }
    if (config is WorkoutConfig) {
      return (current: currentRound, total: config.totalRounds);
    }
    return null;
  }

  void _handleStartTap() {
    final engine = _engine;
    if (engine == null || _started) return;
    HapticFeedback.mediumImpact();
    setState(() => _started = true);
    engine.start();
  }

  void _handlePauseResume() {
    final engine = _engine;
    if (engine == null) return;
    if (engine.state.isPaused) {
      engine.resume();
    } else {
      engine.pause();
    }
  }

  void _handleStop() {
    final engine = _engine;
    if (engine == null) return;

    // Capture localizations from the screen context before showing the
    // dialog — simpler than re-resolving via dialogContext and avoids
    // surprises if the screen's localization delegate changes mid-flight.
    final l10n = AppLocalizations.of(context)!;

    // Auto-pause while the dialog is open so the countdown doesn't drain out
    // from under the user while they decide.
    final wasAlreadyPaused = engine.state.isPaused;
    if (!wasAlreadyPaused) {
      engine.pause();
    }

    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x1AF5C518), width: 1),
        ),
        title: Text(
          l10n.endWorkoutTitle,
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 2,
          ),
        ),
        content: Text(
          l10n.endWorkoutBody,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF8A8A8A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancelAction,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: const Color(0xFF8A8A8A),
                letterSpacing: 2,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.endAction,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: const Color(0xFFF5C518),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    ).then((confirmed) {
      if (!mounted) return;
      if (confirmed == true) {
        // User-initiated END is an abandon, not a completion — suppress
        // bell_end. Claim the pop via _popped so _onEngineChange's
        // phase-advance listener doesn't fire a duplicate pop.
        _popped = true;
        _engine?.endWorkout(playCompletionCue: false);
        // Tiny delay so the engine finishes its phase transition before
        // the route change (keeps the UI stable during teardown).
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) context.pop();
        });
      } else if (!wasAlreadyPaused) {
        // Dialog was cancelled and the engine was running before — resume.
        _engine?.resume();
      }
    });
  }

  @override
  void dispose() {
    // Step 5.4: cancel any in-flight cues on the app-wide AudioService
    // singleton so orphaned playback never leaks onto the home screen
    // after the workout ends. Not awaited — dispose() stays sync; the
    // `_cancelled` flag flips immediately and pending player.stop() calls
    // resolve in the background.
    // Only stop in-flight audio when the workout did NOT complete naturally.
    // Natural completion lets bell_end.mp3 finish playing across the route
    // change to /complete — the user expects to hear the full triple bell
    // even as the screen transitions. Abandons (STOP→END), app
    // backgrounding, and navigation away all still hit stopAll() so we
    // never leak playback onto unrelated screens.
    if (!_completedNaturally) {
      unawaited(AudioService.instance.stopAll());
    }
    final engine = _engine;
    if (engine != null) {
      engine.removeListener(_onEngineChange);
      engine.dispose();
    }
    // Release the wakelock so the home screen's normal system timeout
    // resumes. dispose() is sync; fire-and-forget with try/catch inside.
    unawaited(_safeWakelock(enable: false));
    super.dispose();
  }

  /// Toggles the system wakelock with try/catch so platform errors never
  /// bubble into the workout flow. Log-only on failure via debugPrint.
  Future<void> _safeWakelock({required bool enable}) async {
    try {
      if (enable) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e) {
      debugPrint(
        'WakelockPlus.${enable ? 'enable' : 'disable'} failed: $e',
      );
    }
  }

  /// DEV-ONLY: tap on SKIP fast-forwards 10s. Long-press fast-forwards
  /// 60s. Both route through the engine's [debugSkipForward] which
  /// shifts time anchors (NOT mutable remaining-time state) and
  /// suppresses cue dispatch during the multi-phase chain so skipping
  /// across boundaries doesn't trigger a barrage of bells. Tree-shaken
  /// from release builds via [kDebugMode]. Haptic is fired by the
  /// button widget itself.
  void _handleSkip() {
    if (!kDebugMode) return;
    _engine?.debugSkipForward(10);
  }

  void _handleSkipLong() {
    if (!kDebugMode) return;
    _engine?.debugSkipForward(60);
  }

  /// Maps the engine's phase to the user-facing label shown above the ring.
  /// During work/rest the label IS the round counter ("ROUND 1 / 12"); the
  /// _RoundCard widget below the buttons is gone in this layout. Returns
  /// `null` for [WorkoutPhase.complete] so the route can unwind silently.
  /// Falls back to plain phase strings ("WORK", "REST") only when the
  /// round counter is unavailable (e.g., Smoker transitions).
  String? _resolvePhaseLabel(
    WorkoutPhase phase,
    AppLocalizations l10n,
    ({int current, int total})? roundForCounter,
  ) {
    switch (phase) {
      case WorkoutPhase.preCountdown:
        return l10n.phaseGetReady;
      case WorkoutPhase.work:
        return roundForCounter != null
            ? l10n.roundLabel(
                roundForCounter.current.toString(),
                roundForCounter.total.toString(),
              )
            : l10n.phaseWork;
      case WorkoutPhase.rest:
        return roundForCounter != null
            ? l10n.roundLabel(
                roundForCounter.current.toString(),
                roundForCounter.total.toString(),
              )
            : l10n.phaseRest;
      case WorkoutPhase.complete:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF000000),
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _engine ?? const AlwaysStoppedAnimation<double>(0),
            builder: (context, _) {
              final engine = _engine;
              final bool isPaused = engine?.state.isPaused ?? false;

              final WorkoutPhase phase =
                  engine?.state.phase ?? WorkoutPhase.preCountdown;

              // Display math: CEIL remaining-ms-to-seconds so each whole second is
              // visible for its full duration. A 45-second GET READY counts down
              // visibly: 45 → 44 → ... → 3 → 2 → 1, then the bell fires (engine
              // reaches 0ms) and the next phase begins at its full duration on
              // display (e.g., 3:00 for a 180s work round).
              //
              // Why ceil over floor: floor would tick from "1" straight to "0",
              // and the display would sit on "0" for ~1 second before the engine's
              // remainingMs hit 0 and the bell fired. The user perceives that as
              // a dead second between phases. With ceil, "1" is the final visible
              // value, the bell fires as it would tick to "0", and the next phase
              // takes over the display before "0" is rendered for any meaningful
              // time.
              //
              // Engine timing is unchanged — bell still fires at true 0ms boundary.
              // Round duration is exact (180s of work, 60s of rest, 45s of get
              // ready). This is purely a display formula change.
              final int remainingSec = engine == null
                  ? 45
                  : (_started
                      ? () {
                          final ms = engine.state.phaseRemaining.inMilliseconds;
                          if (ms <= 0) return 0;
                          return ((ms + 999) ~/ 1000).clamp(0, 9999);
                        }()
                      : engine.state.phaseDuration.inSeconds);

              // Pre-countdown reads as a hype countdown (raw seconds).
              // Work + rest read as a clock (M:SS / :SS).
              final String digitText = (phase == WorkoutPhase.preCountdown)
                  ? remainingSec.toString()
                  : formatMmSs(remainingSec);

              final double progress = (!_started || engine == null)
                  ? 1.0
                  : (engine.state.phaseRemaining.inMilliseconds /
                          engine.state.phaseDuration.inMilliseconds)
                      .clamp(0.0, 1.0);

              final Color phaseColor = colorForPhase(phase);
              // Ring + the big digit stay white-on-phase-color; the new
              // label (round counter) takes its color directly from
              // colorForPhase so green = work, red = rest, gold = GET READY.
              final Color digitColor = digitColorForPhase(phase);

              final int? currentBlockIndex =
                  engine?.state.currentBlockIndex;
              final WorkoutBlockType? blockType = engine?.state.blockType;
              final bool isSmoker = engine?.config is SmokerConfig;
              final int totalContentBlocks = engine?.config is SmokerConfig
                  ? (engine!.config as SmokerConfig).totalContentBlocks
                  : 0;
              final bool showBlockLabel = _started &&
                  isSmoker &&
                  currentBlockIndex != null &&
                  blockType != null;

              final ({int current, int total})? roundForCounter =
                  engine == null
                      ? null
                      : _roundForCounter(
                          config: engine.config,
                          phase: phase,
                          currentRound: engine.state.currentRound,
                          currentBlockIndex: currentBlockIndex,
                          blockType: blockType,
                        );

              final String? phaseLabel =
                  _resolvePhaseLabel(phase, l10n, roundForCounter);
              final bool showPhaseLabel = _started && phaseLabel != null;

              final bool showTotalCard = engine != null &&
                  (phase == WorkoutPhase.work || phase == WorkoutPhase.rest);
              // Bug 4 (2026-04-28): the underlying _remainingTotalSeconds
              // math includes preCountdown in the total anchor, which made
              // the displayed TOTAL read 0:46 when phase remaining read
              // 0:01 at the end of the final work block — the 45s gap was
              // the unspent preCountdown reservation. The dual-zero
              // contract (TOTAL hits :00 the same instant final phase
              // hits :00) is enforced HERE at the display layer by
              // subtracting preCountdown.inSeconds from the rendered
              // value during content phases. The underlying math (and
              // its 20 unit tests in timer_screen_smoker_total_time_test)
              // stay intact.
              int rawTotalRemainingSec = 0;
              if (engine != null) {
                rawTotalRemainingSec = _remainingTotalSeconds(
                  engine.config,
                  phase,
                  engine.state.currentRound,
                  engine.state.phaseRemaining.inMilliseconds,
                  currentBlockIndex: currentBlockIndex,
                  blockType: blockType,
                );
              }
              final int preCountdownSec = engine == null
                  ? 0
                  : (engine.config is SmokerConfig
                      ? (engine.config as SmokerConfig)
                          .preCountdown
                          .inSeconds
                      : (engine.config as WorkoutConfig)
                          .preCountdown
                          .inSeconds);
              final int totalRemainingSec = engine == null
                  ? 0
                  : (phase == WorkoutPhase.preCountdown ||
                          phase == WorkoutPhase.complete)
                      ? rawTotalRemainingSec
                      : (rawTotalRemainingSec - preCountdownSec)
                          .clamp(0, 9999);

              return Stack(
                children: [
                  // Ring + digit + bottom section wrapped in a tap target so
                  // only the pre-tap idle state responds (buttons sit above).
                  GestureDetector(
                    onTap: _started ? null : _handleStartTap,
                    behavior: HitTestBehavior.opaque,
                    // Fill the SafeArea so Spacers can distribute slack
                    // vertically. With BlockLabel added in Smoker mode,
                    // the prior Center+min-height column overflowed
                    // ~50px on S23 Ultra; flexing top/middle/bottom
                    // spacers keeps the same visual rhythm at any
                    // viewport height.
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        const Spacer(flex: 1),
                        if (showBlockLabel) ...[
                          BlockLabel(
                            currentBlockIndex: currentBlockIndex,
                            blockType: blockType,
                            totalContentBlocks: totalContentBlocks,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (showPhaseLabel) ...[
                          Text(
                            phaseLabel,
                            style: GoogleFonts.bebasNeue(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: phaseColor,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        SizedBox(
                          width: 380,
                          height: 380,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(380, 380),
                                painter: _CountdownRingPainter(
                                  progress: progress,
                                  arcColor: phaseColor,
                                  trackColor: const Color(0x1AF5C518),
                                  strokeWidth: 6,
                                ),
                              ),
                              Text(
                                digitText,
                                style: GoogleFonts.bebasNeue(
                                  fontSize: 220,
                                  fontWeight: FontWeight.w700,
                                  color: digitColor,
                                  letterSpacing: 0,
                                  height: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(flex: 1),
                        if (!_started)
                          Text(
                            l10n.tapToStartHint,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w400,
                              color: const Color(0xFF8A8A8A),
                              letterSpacing: 4,
                            ),
                          )
                        else
                          // Button row: PAUSE + STOP in release builds
                          // (140×56 each). In debug, a SKIP button joins
                          // the row and all three shrink to 100×56 so the
                          // total (100*3 + 16*2 = 332dp) fits S23's 411dp
                          // logical width with margin — 140×56 × 3 would
                          // blow past at 436dp.
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _TimerActionButton(
                                label: isPaused
                                    ? l10n.resumeButton
                                    : l10n.pauseButton,
                                isPrimary: true,
                                width: kDebugMode ? 100 : 140,
                                onTap: _handlePauseResume,
                              ),
                              const SizedBox(width: 16),
                              _TimerActionButton(
                                label: l10n.stopButton,
                                isPrimary: false,
                                width: kDebugMode ? 100 : 140,
                                onTap: _handleStop,
                              ),
                              if (kDebugMode) ...[
                                const SizedBox(width: 16),
                                _TimerActionButton(
                                  label: 'SKIP',
                                  isPrimary: false,
                                  isDebug: true,
                                  width: 100,
                                  onTap: _handleSkip,
                                  onLongPress: _handleSkipLong,
                                ),
                              ],
                            ],
                          ),
                        if (showTotalCard) ...[
                          const SizedBox(height: 16),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                            child: _TotalTimeCard(
                              label: l10n.totalTimeCardLabel,
                              remainingTotalSeconds: totalRemainingSec,
                            ),
                          ),
                        ],
                        const Spacer(flex: 1),
                      ],
                    ),
                  ),
                  // Dim overlay — sits above the ring/digit, below the buttons.
                  // IgnorePointer keeps the underlying GestureDetector AND the
                  // button row tappable (buttons render in the GestureDetector's
                  // column above and aren't covered).
                  if (isPaused)
                    const Positioned.fill(
                      child: IgnorePointer(
                        child: ColoredBox(color: Color(0x99000000)),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimerActionButton extends StatelessWidget {
  const _TimerActionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    this.width = 140,
    this.isDebug = false,
    this.onLongPress,
  });

  final String label;
  final VoidCallback onTap;

  /// Primary = gold-tinted (PAUSE / RESUME). Non-primary = neutral (STOP).
  final bool isPrimary;

  /// Fixed width. Defaults to 140 for the production two-button row; shrinks
  /// to 100 when the debug SKIP button makes it a three-button row.
  final double width;

  /// Debug-only variant (SKIP). Muted grey outline + grey text, light
  /// haptic instead of medium. Hidden from release builds at the call site
  /// via `if (kDebugMode)`.
  final bool isDebug;

  /// Optional long-press handler. Used by the debug SKIP button to
  /// distinguish a 10s tap-skip from a 60s long-press-skip; null on the
  /// production PAUSE / STOP buttons. Long-press fires a medium-impact
  /// haptic to differentiate it from the light-impact tap.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isDebug
        ? const Color(0xFF8A8A8A)
        : (isPrimary
            ? const Color(0xFFF5C518)
            : const Color(0x33FFFFFF));
    final Color textColor = isDebug
        ? const Color(0xFF8A8A8A)
        : (isPrimary
            ? const Color(0xFFF5C518)
            : const Color(0xFFFFFFFF));

    return GestureDetector(
      onTap: () {
        if (isDebug) {
          HapticFeedback.lightImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
        onTap();
      },
      onLongPress: onLongPress == null
          ? null
          : () {
              HapticFeedback.mediumImpact();
              onLongPress!();
            },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          border: Border.all(color: borderColor, width: 1),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: GoogleFonts.bebasNeue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textColor,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
}

/// Round counter card — compact readout below the action buttons during
/// work/rest phases. Same surface color + gold-tinted border as the home
/// screen preset cards so the design system stays coherent.
///
/// Currently unused: the round counter moved up into the phase-label slot
/// above the ring. Class is parked here intentionally so the layout can be
/// revived without a re-write if a future design wants both label + card.
// ignore: unused_element
class _RoundCard extends StatelessWidget {
  const _RoundCard({
    required this.label,
    required this.currentRound,
    required this.totalRounds,
  });

  final String label;
  final int currentRound;
  final int totalRounds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0x1AF5C518), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label $currentRound/$totalRounds',
        style: GoogleFonts.bebasNeue(
          fontSize: 40,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
          letterSpacing: 2,
        ),
      ),
    );
  }
}

/// Progress ring that drains clockwise from 12 o'clock.
/// [progress] = 1.0 → full circle; 0.0 → empty. [arcColor] changes per phase
/// (gold pre-countdown, green during work, red during rest). The dim
/// background track stays gold-tinted — it's a structural element, not
/// phase state.
class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.arcColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color arcColor;
  final Color trackColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.shortestSide - strokeWidth) / 2;

    final Paint trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final Paint activePaint = Paint()
        ..color = arcColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      // Start at -π/2 (top, 12 o'clock); sweep clockwise by progress * 2π.
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        progress * 2 * math.pi,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CountdownRingPainter old) =>
      old.progress != progress ||
      old.arcColor != arcColor ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

/// Total workout time remaining card — dominant bottom-screen element on
/// the timer. Stacks a small grey "TOTAL" header above the big white M:SS
/// digits so the time-remaining figure reads from across the gym. Stretches
/// to fill its parent's width; height is locked to 120 to seat cleanly
/// inside the timer column's bottom Spacer.
class _TotalTimeCard extends StatelessWidget {
  const _TotalTimeCard({
    required this.label,
    required this.remainingTotalSeconds,
  });

  final String label;
  final int remainingTotalSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0x1AF5C518), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A8A8A),
              letterSpacing: 2,
            ),
          ),
          Text(
            formatMmSs(remainingTotalSeconds),
            style: GoogleFonts.bebasNeue(
              fontSize: 80,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFFFFF),
              letterSpacing: 2,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
