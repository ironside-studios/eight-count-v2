import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../models/custom_config.dart';
import '../services/custom_preset_service.dart';

class CustomBuilderScreen extends StatefulWidget {
  const CustomBuilderScreen({super.key, required this.initialConfig});

  final CustomConfig initialConfig;

  @override
  State<CustomBuilderScreen> createState() => _CustomBuilderScreenState();
}

class _CustomBuilderScreenState extends State<CustomBuilderScreen> {
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _muted = Color(0xFF8A8A8A);

  late CustomConfig _draft;
  late TextEditingController _nameController;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialConfig;
    _nameController = TextEditingController(text: _draft.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  // --- Validators wired to localized strings ---

  String? _validateName(String name, AppLocalizations l10n) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return l10n.customBuilderValidationNameRequired;
    if (trimmed.length > 30) return l10n.customBuilderValidationNameTooLong;
    if (!RegExp(r'^[a-zA-Z0-9\sÀ-ſ]+$').hasMatch(trimmed)) {
      return l10n.customBuilderValidationNameInvalid;
    }
    return null;
  }

  bool get _isValid {
    return _validateName(_draft.name,
                AppLocalizations.of(context)!) ==
            null &&
        CustomConfig.validateRounds(_draft.rounds) == null &&
        CustomConfig.validateWorkSeconds(_draft.workSeconds) == null &&
        CustomConfig.validateRestSeconds(_draft.restSeconds) == null;
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context)!;
    final err = _validateName(_draft.name, l10n);
    if (err != null) {
      setState(() => _nameError = err);
      return;
    }
    try {
      await CustomPresetService.instance.saveSlot(_draft);
      if (!mounted) return;
      Navigator.of(context).pop(_draft);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message.toString())),
      );
    }
  }

  Future<void> _delete() async {
    HapticFeedback.mediumImpact();
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg,
        title: Text(
          l10n.customBuilderDeleteDialogTitle(_draft.name),
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          l10n.customBuilderDeleteDialogBody,
          style: GoogleFonts.inter(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.inter(color: _muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.delete,
              style: GoogleFonts.inter(color: const Color(0xFFE53935)),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CustomPresetService.instance.clearSlot(_draft.slotIndex);
    if (!mounted) return;
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = widget.initialConfig.isSaved
        ? l10n.customBuilderEditTitle
        : l10n.customBuilderNewTitle;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _gold),
        title: Text(
          title,
          style: GoogleFonts.bebasNeue(
            fontSize: 22,
            color: _gold,
            letterSpacing: 1.5,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _nameField(l10n),
              const SizedBox(height: 24),
              _roundsSection(l10n),
              const SizedBox(height: 24),
              _durationSection(
                label: l10n.customBuilderWorkLabel,
                seconds: _draft.workSeconds,
                min: 10,
                max: 600,
                step: 5,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(workSeconds: v)),
              ),
              const SizedBox(height: 24),
              _durationSection(
                label: l10n.customBuilderRestLabel,
                seconds: _draft.restSeconds,
                min: 5,
                max: 300,
                step: 5,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(restSeconds: v)),
              ),
              const SizedBox(height: 24),
              _totalPreview(l10n),
              const SizedBox(height: 24),
              _saveButton(l10n),
              if (widget.initialConfig.isSaved) ...[
                const SizedBox(height: 12),
                _deleteButton(l10n),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          color: _muted,
          letterSpacing: 2,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _nameField(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(l10n.customBuilderNameLabel),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          maxLength: 30,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            counterStyle: GoogleFonts.inter(color: _muted, fontSize: 11),
            errorText: _nameError,
            errorStyle: const TextStyle(color: Color(0xFFE53935)),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _muted),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: _gold, width: 2),
            ),
          ),
          onChanged: (v) {
            setState(() {
              _draft = _draft.copyWith(name: v);
              _nameError = null;
            });
          },
        ),
      ],
    );
  }

  /// Stepper-flanked numeric value for ROUNDS, WORK, REST. Tap = single
  /// step, hold = repeat at 100ms intervals until release. Buttons
  /// disable at bounds.
  Widget _stepperRow({
    required int value,
    required int min,
    required int max,
    required int step,
    required String formatted,
    required ValueChanged<int> onChanged,
    required double valueFontSize,
  }) {
    final atMin = value <= min;
    final atMax = value >= max;
    return Row(
      children: [
        _StepperButton(
          icon: Icons.remove,
          enabled: !atMin,
          onStep: () {
            final next = (value - step).clamp(min, max);
            if (next != value) onChanged(next);
          },
        ),
        Expanded(
          child: Center(
            child: Text(
              formatted,
              style: GoogleFonts.bebasNeue(
                fontSize: valueFontSize,
                color: _gold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          enabled: !atMax,
          onStep: () {
            final next = (value + step).clamp(min, max);
            if (next != value) onChanged(next);
          },
        ),
      ],
    );
  }

  Widget _roundsSection(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(l10n.customBuilderRoundsLabel),
        const SizedBox(height: 8),
        _stepperRow(
          value: _draft.rounds,
          min: 1,
          max: 30,
          step: 1,
          formatted: '${_draft.rounds}',
          valueFontSize: 32,
          onChanged: (v) =>
              setState(() => _draft = _draft.copyWith(rounds: v)),
        ),
      ],
    );
  }

  Widget _durationSection({
    required String label,
    required int seconds,
    required int min,
    required int max,
    required int step,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        _stepperRow(
          value: seconds,
          min: min,
          max: max,
          step: step,
          formatted: _formatDuration(seconds),
          valueFontSize: 28,
          onChanged: onChanged,
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _gold,
            inactiveTrackColor: _gold.withValues(alpha: 0.25),
            thumbColor: _gold,
            overlayColor: _gold.withValues(alpha: 0.15),
          ),
          child: Slider(
            value: seconds.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: ((max - min) ~/ step),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              final snapped = ((v / step).round() * step).clamp(min, max);
              onChanged(snapped);
            },
          ),
        ),
      ],
    );
  }

  Widget _totalPreview(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _sectionLabel(l10n.customBuilderTotalLabel),
          const SizedBox(height: 8),
          Text(
            _formatDuration(_draft.totalWorkoutSeconds),
            style: GoogleFonts.bebasNeue(
              fontSize: 28,
              color: _gold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.customBuilderTotalSubtitle,
            style: GoogleFonts.inter(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(AppLocalizations l10n) {
    final enabled = _isValid;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: enabled ? _save : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: _gold,
            foregroundColor: Colors.black,
            disabledBackgroundColor: _gold,
            disabledForegroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            l10n.customBuilderSaveButton,
            style: GoogleFonts.bebasNeue(
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteButton(AppLocalizations l10n) {
    return TextButton(
      onPressed: _delete,
      child: Text(
        l10n.customBuilderDeleteButton,
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFE53935),
        ),
      ),
    );
  }
}

/// Reusable +/- button used by ROUNDS, WORK, and REST sections. Tap
/// fires `onStep` once with a light-impact haptic. Long-press (hold)
/// fires `onStep` every 100ms with a haptic per repeat until released.
/// Disabled state is greyed and ignores all gestures.
class _StepperButton extends StatefulWidget {
  const _StepperButton({
    required this.icon,
    required this.enabled,
    required this.onStep,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onStep;

  @override
  State<_StepperButton> createState() => _StepperButtonState();
}

class _StepperButtonState extends State<_StepperButton> {
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _step() {
    if (!widget.enabled) return;
    HapticFeedback.lightImpact();
    widget.onStep();
  }

  void _onLongPressStart(_) {
    if (!widget.enabled) return;
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) {
        // Stop the timer if the bound was reached during repeats so
        // the button doesn't keep emitting haptics with no movement.
        if (!widget.enabled) {
          _holdTimer?.cancel();
          _holdTimer = null;
          return;
        }
        _step();
      },
    );
  }

  void _onLongPressEnd(_) {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.enabled
        ? const Color(0xFFD4A017)
        : const Color(0xFF8A8A8A).withValues(alpha: 0.3);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _step : null,
      onLongPressStart: widget.enabled ? _onLongPressStart : null,
      onLongPressEnd: widget.enabled ? _onLongPressEnd : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(widget.icon, color: color, size: 24),
      ),
    );
  }
}
