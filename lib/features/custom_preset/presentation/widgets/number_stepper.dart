import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Stepper widget used by the custom-preset editor.
///
/// [-] [value] [+] horizontal row. Tap to step by one "unit" (unit size is
/// dynamic — e.g., work duration uses 5s steps under 60s, 10s 60-300s, 30s
/// above). Long-press on either button accelerates: first tick 100ms, then
/// 50ms after 1s. Bound-hit fires [HapticFeedback.heavyImpact] and stops
/// the accel. Every normal step fires [HapticFeedback.lightImpact].
class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.stepFor,
    this.display,
    this.label,
  });

  final int value;
  final int min;
  final int max;

  /// Callback fired on each step. Parent widget owns the state.
  final ValueChanged<int> onChanged;

  /// Returns the step size to apply when the user taps +/- while the
  /// current value is [currentValue]. Used to produce the 5s/10s/30s
  /// bucket behaviour on duration pickers.
  final int Function(int currentValue) stepFor;

  /// Optional display formatter (e.g., `formatMmSs`).
  final String Function(int)? display;

  /// Optional label rendered above the stepper (e.g., "ROUNDS").
  final String? label;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  Timer? _accelTimer;

  @override
  void dispose() {
    _accelTimer?.cancel();
    super.dispose();
  }

  void _step({required bool increasing}) {
    final int step = widget.stepFor(widget.value);
    final int candidate = increasing
        ? widget.value + step
        : widget.value - step;
    final int clamped = candidate.clamp(widget.min, widget.max);
    if (clamped == widget.value) {
      // At bound — heavy haptic, stop any accel.
      HapticFeedback.heavyImpact();
      _stopAccel();
      return;
    }
    HapticFeedback.lightImpact();
    widget.onChanged(clamped);
  }

  void _startAccel({required bool increasing}) {
    _accelTimer?.cancel();
    int ticks = 0;
    _accelTimer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      _step(increasing: increasing);
      if (_accelTimer == null) return; // _step hit bound and cancelled us
      ticks++;
      if (ticks == 10) {
        // 1s elapsed at 100ms intervals → switch to 50ms.
        t.cancel();
        _accelTimer = Timer.periodic(
          const Duration(milliseconds: 50),
          (_) => _step(increasing: increasing),
        );
      }
    });
  }

  void _stopAccel() {
    _accelTimer?.cancel();
    _accelTimer = null;
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
              onTap: () => _step(increasing: false),
              onLongPressStart: () => _startAccel(increasing: false),
              onLongPressEnd: _stopAccel,
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
              onTap: () => _step(increasing: true),
              onLongPressStart: () => _startAccel(increasing: true),
              onLongPressEnd: _stopAccel,
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
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressEnd,
    required this.isDisabled,
  });

  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final VoidCallback onLongPressEnd;
  final bool isDisabled;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final Color gold = const Color(0xFFF5C518);
    final Color disabled = gold.withValues(alpha: 0.3);
    final Color color = widget.isDisabled ? disabled : gold;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPressStart: (_) => widget.onLongPressStart(),
      onLongPressEnd: (_) => widget.onLongPressEnd(),
      onLongPressCancel: widget.onLongPressEnd,
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
