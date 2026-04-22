import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:eight_count/core/engine/workout_engine.dart';
import 'package:eight_count/core/models/workout_config.dart';
import 'package:eight_count/core/models/workout_phase.dart';
import 'package:eight_count/main.dart' show audioService;

/// First real timer screen — scoped to the pre-countdown phase only.
///
/// Flow:
///   1. Screen mounts, engine is constructed (boxing preset) but NOT started.
///   2. Full gold ring + static "45" digit + "TAP TO START" hint.
///   3. User taps anywhere → engine.start() begins the 45s countdown, the
///      ring drains clockwise from 12 o'clock, the digit updates per frame,
///      and PAUSE/STOP controls replace the hint.
///   4. PAUSE freezes the ring + digit and dims the screen; RESUME unfreezes.
///   5. STOP opens a confirmation dialog; END fires bell_end and pops home.
///   6. Engine fires wood_clack at 11s remaining, bell_start at 0.
///   7. Engine advances preCountdown → work; [_onEngineChange] catches the
///      transition and pops back to home (real work/rest/complete UI lands
///      in Step 3.2.1).
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
    if (engine.state.phase != WorkoutPhase.preCountdown) {
      _popped = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pop();
      });
    }
    // No setState — AnimatedBuilder in build() handles rebuilds.
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
          'END WORKOUT?',
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 2,
          ),
        ),
        content: Text(
          'Progress will not be saved.',
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF8A8A8A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'CANCEL',
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
              'END',
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
        // User confirmed end → fire bell_end via engine, claim the pop so
        // _onEngineChange's phase-advance listener doesn't also fire one.
        _popped = true;
        _engine?.endWorkout();
        // Small delay so bell_end audio gets a moment to start before the
        // route change (just_audio session survives navigation regardless).
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

  @override
  Widget build(BuildContext context) {
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

              final int displayedSeconds = engine == null
                  ? 45
                  : (_started
                      ? (engine.state.phaseRemaining.inMilliseconds / 1000)
                          .ceil()
                          .clamp(0, 999)
                      : engine.state.phaseDuration.inSeconds);

              final double progress = (!_started || engine == null)
                  ? 1.0
                  : (engine.state.phaseRemaining.inMilliseconds /
                          engine.state.phaseDuration.inMilliseconds)
                      .clamp(0.0, 1.0);

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
                                    color: const Color(0xFFF5C518),
                                    trackColor: const Color(0x1AF5C518),
                                    strokeWidth: 6,
                                  ),
                                ),
                                Text(
                                  '$displayedSeconds',
                                  style: GoogleFonts.bebasNeue(
                                    fontSize: 220,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFF5C518),
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
                              'TAP TO START',
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
                                  label: isPaused ? 'RESUME' : 'PAUSE',
                                  isPrimary: true,
                                  onTap: _handlePauseResume,
                                ),
                                const SizedBox(width: 16),
                                _TimerActionButton(
                                  label: 'STOP',
                                  isPrimary: false,
                                  onTap: _handleStop,
                                ),
                              ],
                            ),
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

/// Gold progress ring that drains clockwise from 12 o'clock.
/// [progress] = 1.0 → full circle; 0.0 → empty.
class _CountdownRingPainter extends CustomPainter {
  _CountdownRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
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
        ..color = color
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
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
