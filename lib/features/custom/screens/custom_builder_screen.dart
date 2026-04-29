import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

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

  bool get _isValid {
    return CustomConfig.validateName(_draft.name) == null &&
        CustomConfig.validateRounds(_draft.rounds) == null &&
        CustomConfig.validateWorkSeconds(_draft.workSeconds) == null &&
        CustomConfig.validateRestSeconds(_draft.restSeconds) == null;
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final err = CustomConfig.validateName(_draft.name);
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _bg,
        title: Text(
          "Delete '${_draft.name}'?",
          style: GoogleFonts.inter(color: Colors.white),
        ),
        content: Text(
          'This cannot be undone.',
          style: GoogleFonts.inter(color: _muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: _muted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
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
    final title = widget.initialConfig.isSaved ? 'Edit Workout' : 'New Workout';
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
              _nameField(),
              const SizedBox(height: 24),
              _roundsStepper(),
              const SizedBox(height: 24),
              _durationSlider(
                label: 'WORK',
                seconds: _draft.workSeconds,
                min: 10,
                max: 600,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(workSeconds: v)),
              ),
              const SizedBox(height: 24),
              _durationSlider(
                label: 'REST',
                seconds: _draft.restSeconds,
                min: 5,
                max: 300,
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(restSeconds: v)),
              ),
              const SizedBox(height: 24),
              _totalPreview(),
              const SizedBox(height: 24),
              _saveButton(),
              if (widget.initialConfig.isSaved) ...[
                const SizedBox(height: 12),
                _deleteButton(),
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

  Widget _nameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('WORKOUT NAME'),
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

  Widget _roundsStepper() {
    final atMin = _draft.rounds <= 1;
    final atMax = _draft.rounds >= 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel('ROUNDS'),
        const SizedBox(height: 8),
        Row(
          children: [
            _stepperButton(
              icon: Icons.remove,
              enabled: !atMin,
              onTap: () => setState(
                () => _draft = _draft.copyWith(
                    rounds: (_draft.rounds - 1).clamp(1, 30)),
              ),
            ),
            Expanded(
              child: Center(
                child: Text(
                  '${_draft.rounds}',
                  style: GoogleFonts.bebasNeue(
                    fontSize: 32,
                    color: _gold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
            _stepperButton(
              icon: Icons.add,
              enabled: !atMax,
              onTap: () => setState(
                () => _draft = _draft.copyWith(
                    rounds: (_draft.rounds + 1).clamp(1, 30)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _stepperButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          border: Border.all(
            color: enabled ? _gold : _muted.withValues(alpha: 0.3),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: enabled ? _gold : _muted.withValues(alpha: 0.3),
          size: 24,
        ),
      ),
    );
  }

  Widget _durationSlider({
    required String label,
    required int seconds,
    required int min,
    required int max,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionLabel(label),
        const SizedBox(height: 8),
        Center(
          child: Text(
            _formatDuration(seconds),
            style: GoogleFonts.bebasNeue(
              fontSize: 24,
              color: _gold,
              letterSpacing: 1.5,
            ),
          ),
        ),
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
            divisions: ((max - min) ~/ 5),
            onChanged: (v) {
              HapticFeedback.selectionClick();
              // Snap to 5-second increments.
              final snapped = ((v / 5).round() * 5).clamp(min, max);
              onChanged(snapped);
            },
          ),
        ),
      ],
    );
  }

  Widget _totalPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          _sectionLabel('TOTAL WORKOUT'),
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
            'Excludes 45s get-ready',
            style: GoogleFonts.inter(fontSize: 11, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
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
            'Save Workout',
            style: GoogleFonts.bebasNeue(
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _deleteButton() {
    return TextButton(
      onPressed: _delete,
      child: Text(
        'Delete this slot',
        style: GoogleFonts.inter(
          fontSize: 13,
          color: const Color(0xFFE53935),
        ),
      ),
    );
  }
}
