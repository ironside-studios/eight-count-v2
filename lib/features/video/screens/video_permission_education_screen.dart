import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../generated/l10n/app_localizations.dart';
import '../services/permission_service.dart';

/// Apple App Review-mandated pre-permission education screen.
///
/// Shown the first time the user flips the Video Capture master toggle
/// ON. Pops with a non-null [VideoPermissionState] when the user
/// completes the OS dialog flow, or `null` if they dismiss via
/// "Not now" or system back. Callers are responsible for using the
/// pop result (and `state.allGranted`) to decide whether to keep the
/// master toggle ON.
class VideoPermissionEducationScreen extends StatefulWidget {
  const VideoPermissionEducationScreen({
    super.key,
    PermissionService? permissionService,
  }) : _injectedService = permissionService;

  /// Optional injection point for tests. Production callers omit this
  /// argument and a default [PermissionService] is constructed inside
  /// [State.initState].
  final PermissionService? _injectedService;

  @override
  State<VideoPermissionEducationScreen> createState() =>
      _VideoPermissionEducationScreenState();
}

class _VideoPermissionEducationScreenState
    extends State<VideoPermissionEducationScreen> {
  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFD4A017);

  late final PermissionService _service;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _service = widget._injectedService ?? PermissionService();
  }

  Future<void> _handleContinue() async {
    if (_requesting) return;
    HapticFeedback.mediumImpact();
    setState(() => _requesting = true);

    final VideoPermissionState state;
    try {
      state = await _service.request();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
    if (!mounted) return;

    if (state.allGranted) {
      Navigator.of(context).pop(state);
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    if (state.anyPermanentlyDenied) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.videoPermissionPermanentlyDenied),
          action: SnackBarAction(
            label: l10n.videoOpenSettings,
            onPressed: () {
              _service.openSettings();
            },
          ),
        ),
      );
      return;
    }

    // Plain denial — invite a retry without leaving the screen.
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.videoPermissionDeniedRetry),
        action: SnackBarAction(
          label: l10n.videoEducationContinue,
          onPressed: _handleContinue,
        ),
      ),
    );
  }

  void _handleNotNow() {
    HapticFeedback.lightImpact();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // System-back: ensure caller sees null even if a stray
        // value is in flight.
        if (didPop && result == null) return;
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 48),
                Icon(LucideIcons.video, size: 64, color: _gold),
                const SizedBox(height: 32),
                Text(
                  l10n.videoEducationTitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bebasNeue(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.videoEducationBody,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                _BulletRow(
                  icon: LucideIcons.camera,
                  text: l10n.videoEducationBulletCamera,
                ),
                const SizedBox(height: 12),
                _BulletRow(
                  icon: LucideIcons.mic,
                  text: l10n.videoEducationBulletMic,
                ),
                const Expanded(child: SizedBox.shrink()),
                _PrimaryButton(
                  label: l10n.videoEducationContinue,
                  enabled: !_requesting,
                  onTap: _handleContinue,
                ),
                const SizedBox(height: 12),
                _SecondaryButton(
                  label: l10n.videoEducationNotNow,
                  onTap: _handleNotNow,
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BulletRow extends StatelessWidget {
  const _BulletRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xFFD4A017)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD4A017),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 56,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.bebasNeue(
                fontSize: 18,
                color: Colors.black,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
