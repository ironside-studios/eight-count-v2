import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/segmented_toggle.dart';
import '../../../generated/l10n/app_localizations.dart';
import '../models/video_settings.dart';
import '../services/video_settings_service.dart';

/// Settings → Video Capture panel. Foundation scaffold (Stage Video-1):
/// renders all 7 sections, persists every change through
/// [VideoSettingsService], greys-out the dependent sections when the
/// master toggle is off. Camera hardware is NOT touched from this
/// screen — the engine wiring lives in a later stage.
class VideoSettingsScreen extends StatefulWidget {
  const VideoSettingsScreen({super.key});

  @override
  State<VideoSettingsScreen> createState() => _VideoSettingsScreenState();
}

class _VideoSettingsScreenState extends State<VideoSettingsScreen> {
  /// Hardcoded capture-timing options for the foundation scaffold —
  /// values are seconds-remaining-in-round. The dynamic per-workout
  /// list is wired in a later stage.
  static const List<int> _timingOptions = <int>[150, 120, 90, 60, 30];

  VideoSettings? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await VideoSettingsService.instance.loadSettings();
    if (!mounted) return;
    setState(() => _settings = loaded);
  }

  Future<void> _update(VideoSettings next) async {
    setState(() => _settings = next);
    await VideoSettingsService.instance.saveSettings(next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = _settings;
    return Scaffold(
      backgroundColor: AppColors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: AppColors.gold,
            size: 24,
          ),
          tooltip: l10n.backTooltip,
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          l10n.videoSettingsTitle,
          style: AppTheme.displayFont(
            fontSize: 24,
            color: AppColors.gold,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: s == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _buildBody(l10n, s),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n, VideoSettings s) {
    final bool enabled = s.videoCaptureEnabled;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.base,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Master toggle.
          _ToggleRow(
            title: l10n.videoSettingsEnableTitle,
            subtitle: l10n.videoSettingsEnableSubtitle,
            value: enabled,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              _update(s.copyWith(videoCaptureEnabled: v));
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // 2-7 dim when master is off.
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            opacity: enabled ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !enabled,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 2. Clip Length.
                  _SectionLabel(label: l10n.videoSettingsClipLengthTitle),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedToggle(
                    options: <String>[
                      l10n.videoSettingsClipLength20s,
                      l10n.videoSettingsClipLength30s,
                    ],
                    selectedIndex: s.clipDurationSeconds == 20 ? 0 : 1,
                    onChanged: (i) {
                      _update(
                        s.copyWith(clipDurationSeconds: i == 0 ? 20 : 30),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 3. Camera.
                  _SectionLabel(label: l10n.videoSettingsCameraTitle),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedToggle(
                    options: <String>[
                      l10n.videoSettingsCameraFront,
                      l10n.videoSettingsCameraBack,
                    ],
                    selectedIndex:
                        s.cameraDirection == CameraDirection.front ? 0 : 1,
                    onChanged: (i) {
                      _update(s.copyWith(
                        cameraDirection: i == 0
                            ? CameraDirection.front
                            : CameraDirection.back,
                      ));
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Subtitle(text: l10n.videoSettingsCameraSubtitle),
                  const SizedBox(height: AppSpacing.xl),

                  // 4. Clips Per Round.
                  _SectionLabel(label: l10n.videoSettingsClipsPerRoundTitle),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedToggle(
                    options: const <String>['1', '2', '3'],
                    selectedIndex: (s.clipsPerRound - 1).clamp(0, 2),
                    onChanged: (i) {
                      _update(s.copyWith(clipsPerRound: i + 1));
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 5. Capture Timing — multi-select chips.
                  _SectionLabel(label: l10n.videoSettingsCaptureTimingTitle),
                  const SizedBox(height: AppSpacing.md),
                  _TimingChipRow(
                    options: _timingOptions,
                    selected: s.captureTimestampsRemaining,
                    onChanged: (next) {
                      _update(
                        s.copyWith(captureTimestampsRemaining: next),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 6. Resolution.
                  _SectionLabel(label: l10n.videoSettingsResolutionTitle),
                  const SizedBox(height: AppSpacing.md),
                  SegmentedToggle(
                    options: <String>[
                      l10n.videoSettingsResolutionStandard,
                      l10n.videoSettingsResolutionHigh,
                    ],
                    selectedIndex:
                        s.resolution == VideoResolution.low720 ? 0 : 1,
                    onChanged: (i) {
                      _update(s.copyWith(
                        resolution: i == 0
                            ? VideoResolution.low720
                            : VideoResolution.high1080,
                      ));
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _Subtitle(text: l10n.videoSettingsResolutionSubtitle),
                  const SizedBox(height: AppSpacing.xl),

                  // 7. AI Auto-Pick toggle.
                  _ToggleRow(
                    title: l10n.videoSettingsAiAutoPickTitle,
                    subtitle: l10n.videoSettingsAiAutoPickSubtitle,
                    value: s.aiAutoPickEnabled,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      _update(s.copyWith(aiAutoPickEnabled: v));
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 3,
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w300,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderGold, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppTheme.displayFont(
                    fontSize: 18,
                    color: AppColors.white,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.black,
            activeTrackColor: AppColors.gold,
            inactiveThumbColor: AppColors.greyMuted,
            inactiveTrackColor: AppColors.surfaceCardPressed,
          ),
        ],
      ),
    );
  }
}

class _TimingChipRow extends StatelessWidget {
  const _TimingChipRow({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  /// Seconds-remaining-in-round.
  final List<int> options;
  final List<int> selected;
  final ValueChanged<List<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final int seconds in options)
          _TimingChip(
            label: _formatMmSs(seconds),
            isSelected: selected.contains(seconds),
            onTap: () {
              HapticFeedback.selectionClick();
              final next = List<int>.from(selected);
              if (next.contains(seconds)) {
                next.remove(seconds);
              } else {
                next.add(seconds);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }

  static String _formatMmSs(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class _TimingChip extends StatelessWidget {
  const _TimingChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.gold, width: 1.5),
        ),
        child: Text(
          label,
          style: AppTheme.displayFont(
            fontSize: 16,
            color: isSelected ? AppColors.black : AppColors.gold,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
