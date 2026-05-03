// TODO(admob): replace with real AdMob banner widget when RevenueCat
//   vendor number is in. Should drop `google_mobile_ads`'s
//   `BannerAd` (adaptive) into the same 50dp slot; this placeholder's
//   width/height/SafeArea contract is the layout reservation.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 50dp-tall opaque banner that reserves the AdMob banner slot at the
/// bottom of the home screen. Sits above the Android system nav bar
/// via the bottom-only [SafeArea].
///
/// The opaque `#0A0A0A` background is intentional — it masks the
/// matrix rain behind the home screen so the banner reads as a
/// distinct system-chrome surface, not part of the live background.
class BannerAdPlaceholder extends StatelessWidget {
  const BannerAdPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Container(
        height: 50,
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0A0A0A),
          border: Border(
            top: BorderSide(color: Color(0xFF1A1A1A), width: 1),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          'Ad placeholder · 320×50',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFF8A8A8A),
          ),
        ),
      ),
    );
  }
}
