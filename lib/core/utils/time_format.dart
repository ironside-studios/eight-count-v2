/// Formats a duration in seconds as M:SS (at 60s and above) or :SS (below 60s).
///
/// Examples:
///   formatMmSs(180) -> "3:00"
///   formatMmSs(60)  -> "1:00"
///   formatMmSs(59)  -> ":59"
///   formatMmSs(0)   -> ":00"
///
/// The leading-colon form for sub-60s keeps the big digit's horizontal
/// position visually stable across the 1:00 -> :59 boundary on the timer
/// screen. Negative inputs clamp to ":00".
String formatMmSs(int seconds) {
  final s = seconds.clamp(0, 99 * 60 + 59);
  if (s >= 60) {
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }
  return ':${s.toString().padLeft(2, '0')}';
}
