import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../generated/l10n/app_localizations.dart';

/// Bottom-sheet upsell shown to free-tier users when they tap any
/// Pro-locked card on the home screen (Smoker or Custom). Renders the
/// Pro pitch + a primary "Unlock Pro — $4.99" button (currently a
/// no-op until RevenueCat is wired) and a "Maybe later" dismiss.
///
/// One modal, one CTA, one entitlement: $4.99 unlocks Smoker + Custom
/// + removes ads. When IAP lands, the [_handleUnlock] body becomes the
/// single integration point — both Smoker and Custom unlock from there.
class ProUpsellModal extends StatelessWidget {
  const ProUpsellModal({super.key});

  /// Convenience helper so call sites stay clean:
  ///   `ProUpsellModal.show(context)`
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ProUpsellModal(),
    );
  }

  static const Color _bg = Color(0xFF0A0A0A);
  static const Color _gold = Color(0xFFD4A017);
  static const Color _muted = Color(0xFF8A8A8A);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                l10n.proUpsellTitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.bebasNeue(
                  fontSize: 22,
                  color: _gold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.proUpsellBody,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // TODO(revenuecat): wire to Purchases.purchasePackage when vendor number lands.
              // Single point of integration — both Smoker and Custom unlock from this handler.
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
                    l10n.proUpsellCta('\$4.99'),
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
                  l10n.proUpsellDismiss,
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
