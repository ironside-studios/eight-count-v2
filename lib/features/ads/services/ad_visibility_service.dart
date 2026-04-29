/// Single source of truth for whether the user should see the banner
/// ad slot. Home screen calls [shouldShowBannerAd] and decides whether
/// to render [BannerAdPlaceholder] (or, post-AdMob-wiring, the real
/// banner widget) — visibility is never hardcoded at the call site.
///
/// Singleton via static final instance, matching the project pattern
/// used by [AudioService] in lib/core/services/audio_service.dart.
class AdVisibilityService {
  AdVisibilityService._();

  static final AdVisibilityService instance = AdVisibilityService._();

  /// Returns true while the user is on the free tier (sees ads). Right
  /// now this is a hard-coded `true` — every user is "free" until the
  /// RevenueCat entitlement check is wired.
  ///
  // TODO(revenuecat): replace with RevenueCat entitlement check for
  //   'pro' or 'ai_video_pack'. Pseudocode:
  //     final ent = Purchases.getCustomerInfo().entitlements.active;
  //     return !(ent.containsKey('pro') || ent.containsKey('ai_video_pack'));
  bool shouldShowBannerAd() {
    return true;
  }
}
