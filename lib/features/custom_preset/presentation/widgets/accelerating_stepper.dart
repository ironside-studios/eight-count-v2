import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Shared stepper used by the Custom-preset editor for rounds + work + rest.
///
/// Behaviour:
///   - Single tap  → step by `stepRamp[0]` (the slow tick).
///   - Long-press  → ramp:
///       * first 500 ms of hold   → `stepRamp[0]` every 100 ms
///       * 500 ms – 1500 ms       → `stepRamp[1]` every 100 ms
///       * after 1500 ms          → `stepRamp[2]` every 100 ms
///   - Bound-hit   → [HapticFeedback.heavyImpact] + stops the accel.
///   - Every applied step fires [HapticFeedback.lightImpact].
///
/// Examples:
///   - rounds:  stepRamp: [1, 2, 5]
///   - work:    stepRamp: [1, 5, 10]
///   - rest:    stepRamp: [1, 5, 10]
class AcceleratingStepper extends StatefulWidget {
  const AcceleratingStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.stepRamp,
    this.display,
    this.label,
  }) : assert(stepRamp.length == 3,
            'stepRamp must be exactly [slow, medium, fast]');

  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  /// `[slow, medium, fast]` — step sizes applied at the three ramp tiers.
  /// Single-tap uses `stepRamp[0]`.
  final List<int> stepRamp;

  /// Optional display formatter (e.g. `formatMmSs` for MM:SS).
  final String Function(int)? display;

  /// Optional label rendered above the +/- row (e.g. "ROUNDS").
  final String? label;

  @override
  State<AcceleratingStepper> createState() => _AcceleratingStepperState();
}

class _AcceleratingStepperState extends State<AcceleratingStepper> {
  /// Returns `true` if the step was applied; `false` if a bound was hit
  /// (the caller uses this to stop any ongoing accel).
  bool _apply(int step, {required bool increasing}) {
    final int candidate =
        increasing ? widget.value + step : widget.value - step;
    final int clamped = candidate.clamp(widget.min, widget.max);
    if (clamped == widget.value) {
      HapticFeedback.heavyImpact();
      return false;
    }
    HapticFeedback.lightImpact();
    widget.onChanged(clamped);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final String rendered =
        widget.display?.call(widget.value) ?? widget.value.toString();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: GoogleFonts.bebasNeue(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF8A8A8A),
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _StepperButton(
              icon: LucideIcons.minus,
              stepRamp: widget.stepRamp,
              onStep: (step) => _apply(step, increasing: false),
              isDisabled: widget.value <= widget.min,
            ),
            const SizedBox(width: 24),
            SizedBox(
              width: 140,
              child: Text(
                rendered,
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  fontSize: 56,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFFFFFFF),
                  letterSpacing: 2,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 24),
            _StepperButton(
              icon: LucideIcons.plus,
              stepRamp: widget.stepRamp,
              onStep: (step) => _apply(step, increasing: true),
              isDisabled: widget.value >= widget.max,
            ),
          ],
        ),
      ],
    );
  }
}

class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.stepRamp,
    required this.onStep,
    required this.isDisabled,
  });

  final IconData icon;
  final List<int> stepRamp;

  /// Returns `true` if the step landed; `false` if at bound so the button
  /// can stop the hold timer.
  final bool Function(int step) onStep;
  final bool isDisabled;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  Timer? _holdTimer;
  final Stopwatch _holdStopwatch = Stopwatch();
  bool _pressed = false;

  int _currentStep() {
    final int ms = _holdStopwatch.elapsedMilliseconds;
    final ramp = widget.stepRamp;
    if (ms < 500) return ramp[0];
    if (ms < 1500) return ramp[1];
    return ramp[2];
  }

  void _handleTap() {
    widget.onStep(widget.stepRamp[0]);
  }

  void _startHold() {
    _stopHold();
    _holdStopwatch
      ..reset()
      ..start();
    // Immediate tick so the hold feels responsive — fires at the slow step.
    final applied = widget.onStep(widget.stepRamp[0]);
    if (!applied) {
      _holdStopwatch.stop();
      return;
    }
    _holdTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final ok = widget.onStep(_currentStep());
      if (!ok) _stopHold();
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
    _holdStopwatch.stop();
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color gold = Color(0xFFF5C518);
    final Color color =
        widget.isDisabled ? gold.withValues(alpha: 0.3) : gold;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: _handleTap,
      onLongPressStart: (_) => _startHold(),
      onLongPressEnd: (_) => _stopHold(),
      onLongPressCancel: _stopHold,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          alignment: Alignment.center,
          child: Icon(widget.icon, color: color, size: 28),
        ),
      ),
    );
  }
}
