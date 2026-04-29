import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Bottom-sheet upsell shown to free-tier users when they tap the
/// Custom card on the home screen. Renders the Pro pitch + a primary
/// "Unlock Pro — $4.99" button (currently a no-op until RevenueCat
/// is wired) and a "Maybe later" dismiss.
class CustomUpsellModal extends StatelessWidget {
  const CustomUpsellModal({super.key});

  /// Convenience helper so call sites stay clean:
  ///   `CustomUpsellModal.show(context)`
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const CustomUpsellModal(),
    );
  }

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _muted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _muted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Unlock Custom Workouts',
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  color: _gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Build your own boxing workouts. 3 saved slots, full control.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 24),
              const _FeatureRow(text: 'Custom rounds, work, and rest'),
              const _FeatureRow(text: '3 named saved slots'),
              const _FeatureRow(text: 'No ads'),
              const SizedBox(height: 32),
              // TODO(revenuecat): wire to RevenueCat purchase flow
              //   when vendor number is in. For now this just dismisses.
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Unlock Pro — \$4.99',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 16,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(context).pop();
                },
                child: Text(
                  'Maybe later',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _muted,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(LucideIcons.check, size: 18, color: Color(0xFFD4A017)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
