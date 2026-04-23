import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/utils/time_format.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../domain/custom_preset.dart';
import 'custom_preset_controller.dart';
import 'widgets/number_stepper.dart';

/// Create / edit screen. Pass `null` to create; pass a [CustomPreset] to
/// edit. Accessed via `context.push('/custom/edit', extra: preset?)`.
class CustomPresetEditorScreen extends StatefulWidget {
  const CustomPresetEditorScreen({super.key, this.existing});

  final CustomPreset? existing;

  @override
  State<CustomPresetEditorScreen> createState() =>
      _CustomPresetEditorScreenState();
}

class _CustomPresetEditorScreenState extends State<CustomPresetEditorScreen> {
  late final TextEditingController _nameCtrl;
  late int _rounds;
  late int _workSeconds;
  late int _restSeconds;
  late int _originalNameHash;
  late int _originalRounds;
  late int _originalWorkSeconds;
  late int _originalRestSeconds;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _rounds = existing?.rounds ?? 12;
    _workSeconds = existing?.workSeconds ?? 180;
    _restSeconds = existing?.restSeconds ?? 60;
    _originalNameHash = _nameCtrl.text.hashCode;
    _originalRounds = _rounds;
    _originalWorkSeconds = _workSeconds;
    _originalRestSeconds = _restSeconds;
    _nameCtrl.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _nameCtrl.removeListener(_onNameChanged);
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _isDirty =>
      _nameCtrl.text.hashCode != _originalNameHash ||
      _rounds != _originalRounds ||
      _workSeconds != _originalWorkSeconds ||
      _restSeconds != _originalRestSeconds;

  String? get _validationError => CustomPreset.validate(
        name: _nameCtrl.text,
        rounds: _rounds,
        workSeconds: _workSeconds,
        restSeconds: _restSeconds,
      );

  bool get _isValid => _validationError == null;

  // --- Duration step buckets ---
  int _workStepFor(int v) {
    if (v < 60) return 5;
    if (v < 300) return 10;
    return 30;
  }

  int _restStepFor(int v) => v < 60 ? 5 : 10;

  Future<void> _handleSave() async {
    final error = _validationError;
    if (error != null) {
      HapticFeedback.heavyImpact();
      _showErrorSnack(error);
      return;
    }
    HapticFeedback.mediumImpact();
    final existing = widget.existing;
    final CustomPreset toSave = existing == null
        ? CustomPreset.create(
            name: _nameCtrl.text.trim(),
            rounds: _rounds,
            workSeconds: _workSeconds,
            restSeconds: _restSeconds,
          )
        : existing.copyWith(
            name: _nameCtrl.text.trim(),
            rounds: _rounds,
            workSeconds: _workSeconds,
            restSeconds: _restSeconds,
          );
    final ok = await customPresetController.savePreset(toSave);
    if (!mounted) return;
    if (ok) {
      context.pop();
    } else {
      HapticFeedback.heavyImpact();
      _showErrorSnack(
        customPresetController.errorMessage ?? 'Failed to save workout',
      );
    }
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(color: const Color(0xFFFFFFFF)),
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF141414),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0x1AF5C518), width: 1),
        ),
        title: Text(
          l10n.unsavedChangesTitle,
          style: GoogleFonts.bebasNeue(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFFFFFFF),
            letterSpacing: 2,
          ),
        ),
        content: Text(
          l10n.unsavedChangesBody,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: const Color(0xFF8A8A8A),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.cancel,
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
              l10n.discard,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: const Color(0xFFDC2626),
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;

    return PopScope<void>(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && context.mounted) context.pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(LucideIcons.arrowLeft,
                color: const Color(0xFFF5C518), size: 24),
            onPressed: () async {
              HapticFeedback.selectionClick();
              final ok = await _confirmDiscard();
              if (ok && context.mounted) context.pop();
            },
          ),
          title: Text(
            isEdit ? l10n.editWorkout : l10n.newWorkout,
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF5C518),
              letterSpacing: 3,
            ),
          ),
          centerTitle: true,
          actions: [
            TextButton(
              onPressed: _isValid ? _handleSave : null,
              child: Text(
                l10n.save,
                style: GoogleFonts.bebasNeue(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _isValid
                      ? const Color(0xFFF5C518)
                      : const Color(0xFF8A8A8A),
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _NameField(
                  controller: _nameCtrl,
                  hintText: l10n.workoutName,
                ),
                const SizedBox(height: 32),
                NumberStepper(
                  value: _rounds,
                  min: CustomPreset.kMinRounds,
                  max: CustomPreset.kMaxRounds,
                  stepFor: (_) => 1,
                  label: l10n.rounds,
                  onChanged: (v) => setState(() => _rounds = v),
                ),
                const SizedBox(height: 32),
                NumberStepper(
                  value: _workSeconds,
                  min: CustomPreset.kMinWorkSeconds,
                  max: CustomPreset.kMaxWorkSeconds,
                  stepFor: _workStepFor,
                  display: formatMmSs,
                  label: l10n.work,
                  onChanged: (v) => setState(() => _workSeconds = v),
                ),
                const SizedBox(height: 32),
                NumberStepper(
                  value: _restSeconds,
                  min: CustomPreset.kMinRestSeconds,
                  max: CustomPreset.kMaxRestSeconds,
                  stepFor: _restStepFor,
                  display: formatMmSs,
                  label: l10n.rest,
                  onChanged: (v) => setState(() => _restSeconds = v),
                ),
                const SizedBox(height: 48),
                Text(
                  l10n.preCountdownLocked,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF8A8A8A),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller, required this.hintText});

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    final remaining = CustomPreset.kMaxNameLength - controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLength: CustomPreset.kMaxNameLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          style: GoogleFonts.inter(
            fontSize: 18,
            color: const Color(0xFFFFFFFF),
          ),
          cursorColor: const Color(0xFFF5C518),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.inter(
              fontSize: 18,
              color: const Color(0xFF8A8A8A),
            ),
            counterText: '',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1F1F1F), width: 1),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFFF5C518), width: 1),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$remaining',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF8A8A8A),
            ),
          ),
        ),
      ],
    );
  }
}
