import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../theme/app_theme.dart';

/// Reusable gold segmented-pill toggle.
/// Active option: filled gold pill, black text.
/// Inactive option: gold-outlined pill, gold text.
class SegmentedToggle extends StatelessWidget {
  const SegmentedToggle({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < options.length; i++) ...[
          Expanded(
            child: _SegmentOption(
              label: options[i],
              isSelected: i == selectedIndex,
              onTap: () {
                if (i == selectedIndex) return;
                HapticFeedback.selectionClick();
                onChanged(i);
              },
            ),
          ),
          if (i < options.length - 1) const SizedBox(width: AppSpacing.md),
        ],
      ],
    );
  }
}

class _SegmentOption extends StatefulWidget {
  const _SegmentOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_SegmentOption> createState() => _SegmentOptionState();
}

class _SegmentOptionState extends State<_SegmentOption> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isSelected ? AppColors.gold : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.gold,
              width: 1.5,
            ),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: AppTheme.displayFont(
              fontSize: 18,
              color: widget.isSelected ? AppColors.black : AppColors.gold,
              letterSpacing: 2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
