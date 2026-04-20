/// 8 Count V2 — Timer Constants (Boxing Preset)
/// Locked 4/20/26.
class AppDurations {
  AppDurations._();

  // Boxing preset (V2.0 Free tier)
  static const int preWorkoutCountdownSeconds = 45;
  static const int totalRounds = 12;
  static const int workRoundSeconds = 180;  // 3:00
  static const int restRoundSeconds = 60;   // 1:00

  // Ring color transition: final 15s of work round turns yellow
  static const int workWarningSeconds = 15;

  // Audio cue timing: wood_clack fires at 11s remaining so 1.88s clip ends by 9.12s
  static const int woodClackCueSeconds = 11;
}
