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
///   2. Big "45" digit centered; "TAP TO START" hint underneath.
///   3. User taps anywhere → [_handleStartTap] fires, engine.start() begins
///      the 45s countdown, hint goes invisible (keeps its box to pin layout),
///      digit updates every frame.
///   4. Engine fires wood_clack at 11s remaining, bell_start at 0.
///   5. Engine advances preCountdown → work; [_onEngineChange] catches the
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
    // No setState — AnimatedBuilder in build() handles digit rebuilds.
  }

  void _handleStartTap() {
    final engine = _engine;
    if (engine == null || _started) return;
    HapticFeedback.mediumImpact();
    setState(() => _started = true);
    engine.start();
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
          child: GestureDetector(
            onTap: _started ? null : _handleStartTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedBuilder(
              animation: _engine ?? const AlwaysStoppedAnimation<double>(0),
              builder: (context, _) {
                final engine = _engine;
                final int displayedSeconds = engine == null
                    ? 45
                    : (_started
                        ? (engine.state.phaseRemaining.inMilliseconds / 1000)
                            .ceil()
                            .clamp(0, 999)
                        : engine.state.phaseDuration.inSeconds);
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                      const SizedBox(height: 32),
                      // Keep the hint's layout slot reserved when hidden so
                      // the digit doesn't jump on tap.
                      Opacity(
                        opacity: _started ? 0.0 : 1.0,
                        child: Text(
                          'TAP TO START',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                            color: const Color(0xFF8A8A8A),
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
