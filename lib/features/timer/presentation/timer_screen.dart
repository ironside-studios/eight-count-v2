import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eight_count/core/design/phase_colors.dart';
import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/core/utils/time_format.dart';
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
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key, required this.presetId});

  final String presetId;

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  WorkoutEngine? _engine;
  bool _started = false;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    if (widget.presetId == 'boxing') {
      _engine = WorkoutEngine(
        config: WorkoutConfig.boxing(),
        audio: audioService,
      );
      _engine!.addListener(_onEngineChange);
    } else {
      // TODO Step 3.2.x: handle smoker/custom presets. For now, bounce home —
      // these presets are locked/paywalled and should never route here yet.
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
    // 50ms delay matches _handleStop so bell_end has a moment to start
    // playing before the route change. Intermediate transitions
    // (preCountdown → work, work ↔ rest) stay on this screen; AnimatedBuilder
    // rebuilds handle the label / ring-color / round-card swaps.
    if (engine.state.phase == WorkoutPhase.complete) {
      _popped = true;
      final int totalSeconds = _totalWorkoutSeconds(engine.config);
      final String presetId = widget.presetId;
      Future.delayed(const Duration(milliseconds: 50), () {
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
  static int _totalWorkoutSeconds(WorkoutConfig config) {
    final int workSec = config.workDuration.inSeconds * config.totalRounds;
    final int restSec =
        config.restDuration.inSeconds * (config.totalRounds - 1);
    return workSec + restSec;
  }

  /// Remaining seconds on the whole work+rest cycle (pre-countdown excluded),
  /// derived from live engine state — never stored. Ceil'd so the last second
  /// stays on screen through its full tick.
  ///
  ///   totalMs       = workMs * N   +  restMs * (N - 1)
  ///   elapsed[work] = (round-1) * (workMs + restMs) + (workMs - phaseRemainingMs)
  ///   elapsed[rest] = (round-1) * (workMs + restMs) + workMs + (restMs - phaseRemainingMs)
  static int _remainingTotalSeconds(
    WorkoutConfig config,
    WorkoutPhase phase,
    int currentRound,
    int phaseRemainingMs,
  ) {
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
    final engine = _engine;
    if (engine != null) {
      engine.removeListener(_onEngineChange);
      engine.dispose();
    }
    super.dispose();
  }

  /// Maps the engine's phase to the user-facing label shown above the ring.
  /// Returns `null` for [WorkoutPhase.complete] — the screen is popping, we
  /// don't want a celebratory label flashing as the route unwinds.
  String? _resolvePhaseLabel(WorkoutPhase phase, AppLocalizations l10n) {
    switch (phase) {
      case WorkoutPhase.preCountdown:
        return l10n.phaseGetReady;
      case WorkoutPhase.work:
        return l10n.phaseWork;
      case WorkoutPhase.rest:
        return l10n.phaseRest;
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

              final int remainingSec = engine == null
                  ? 45
                  : (_started
                      ? (engine.state.phaseRemaining.inMilliseconds / 1000)
                          .ceil()
                          .clamp(0, 9999)
                          .toInt()
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

              final String? phaseLabel = _resolvePhaseLabel(phase, l10n);
              final bool showPhaseLabel = _started && phaseLabel != null;
              final bool showRoundCard =
                  engine != null &&
                  (phase == WorkoutPhase.work || phase == WorkoutPhase.rest);
              final bool showTotalCard = showRoundCard;
              final int totalRemainingSec = engine == null
                  ? 0
                  : _remainingTotalSeconds(
                      engine.config,
                      phase,
                      engine.state.currentRound,
                      engine.state.phaseRemaining.inMilliseconds,
                    );

              return Stack(
                children: [
                  // Ring + digit + bottom section wrapped in a tap target so
                  // only the pre-tap idle state responds (buttons sit above).
                  GestureDetector(
                    onTap: _started ? null : _handleStartTap,
                    behavior: HitTestBehavior.opaque,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showPhaseLabel) ...[
                            Text(
                              phaseLabel,
                              style: GoogleFonts.bebasNeue(
                                fontSize: 32,
                                fontWeight: FontWeight.w700,
                                color: phaseColor,
                                letterSpacing: 3,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          SizedBox(
                            width: 320,
                            height: 320,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CustomPaint(
                                  size: const Size(320, 320),
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
                                    color: phaseColor,
                                    letterSpacing: 0,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _TimerActionButton(
                                  label: isPaused
                                      ? l10n.resumeButton
                                      : l10n.pauseButton,
                                  isPrimary: true,
                                  onTap: _handlePauseResume,
                                ),
                                const SizedBox(width: 16),
                                _TimerActionButton(
                                  label: l10n.stopButton,
                                  isPrimary: false,
                                  onTap: _handleStop,
                                ),
                              ],
                            ),
                          if (showRoundCard) ...[
                            const SizedBox(height: 24),
                            _RoundCard(
                              label: l10n.roundCardLabel,
                              currentRound: engine.state.currentRound,
                              totalRounds: engine.state.totalRounds,
                            ),
                          ],
                          if (showTotalCard) ...[
                            const SizedBox(height: 12),
                            _TotalTimeCard(
                              label: l10n.totalTimeCardLabel,
                              remainingTotalSeconds: totalRemainingSec,
                            ),
                          ],
                        ],
                      ),
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
  });

  final String label;
  final VoidCallback onTap;

  /// Primary = gold-tinted (PAUSE / RESUME). Non-primary = neutral (STOP).
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = isPrimary
        ? const Color(0xFFF5C518)
        : const Color(0x33FFFFFF);
    final Color textColor = isPrimary
        ? const Color(0xFFF5C518)
        : const Color(0xFFFFFFFF);

    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 140,
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0x1AF5C518), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label $currentRound/$totalRounds',
        style: GoogleFonts.bebasNeue(
          fontSize: 22,
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

/// Total workout time remaining card — shown below the round card during
/// work/rest phases. Neutral white-on-charcoal so it reads as reference info
/// rather than phase state. Derived from engine state, never stored.
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
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: const Color(0xFF141414),
        border: Border.all(color: const Color(0x1AF5C518), width: 1),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        '$label ${formatMmSs(remainingTotalSeconds)}',
        style: GoogleFonts.bebasNeue(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
          letterSpacing: 2,
        ),
      ),
    );
  }
}
