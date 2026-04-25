/// The kind of period a [WorkoutBlock] represents.
///
/// Used by the engine to dispatch cue routing inside a Smoker workout
/// (different blocks fire different entry cues, and tabata blocks suppress
/// the in-phase wood_clack entirely because their periods are too short
/// for an 11s warning).
enum WorkoutBlockType {
  /// Boxing-style: long work + rest, bell_start on work-entry,
  /// bell_end on work-exit, wood_clack at 11s remaining (work and rest).
  boxing,

  /// Tabata-style: short work + rest, whistle_long on work-entry AND
  /// rest-entry, no wood_clack, silent work-exit (next entry handles cue).
  tabata,

  /// Synthetic 60s rest period inserted between content blocks.
  /// Wood_clack fires at 11s remaining; otherwise silent.
  transition,
}
