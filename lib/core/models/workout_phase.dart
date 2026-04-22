/// Discrete phases of a workout. Ordered by natural progression.
///
/// The UI layer resolves [l10nKey] against AppLocalizations; the enum itself
/// never touches i18n so it stays pure Dart and testable without a MaterialApp.
enum WorkoutPhase {
  /// 45s "GET READY" lead-in before the first work round.
  preCountdown,

  /// Active work period within a round.
  work,

  /// Rest period between rounds.
  rest,

  /// Terminal state — the workout has ended.
  complete;

  /// The ARB key name the UI should resolve for this phase's display label.
  String get l10nKey {
    switch (this) {
      case WorkoutPhase.preCountdown:
        return 'phaseGetReady';
      case WorkoutPhase.work:
        return 'phaseWork';
      case WorkoutPhase.rest:
        return 'phaseRest';
      case WorkoutPhase.complete:
        return 'phaseComplete';
    }
  }
}
