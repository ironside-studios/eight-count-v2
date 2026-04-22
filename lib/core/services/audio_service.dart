/// Audio cue dispatcher used by the workout engine.
///
/// STUB: real playback + stop-before-play overlap enforcement land in a later
/// step (when the just_audio dependency is added and assets are bundled).
/// This file locks the public surface the engine depends on — [play] and
/// [dispose] — so future implementations can drop in without rippling
/// through the engine or its tests.
///
/// Cue name contract (string identifiers, not enums, so ARB/asset lookup
/// stays data-driven):
///   - 'wood_clack'    fires at remaining = 11s, once per phase
///   - 'bell_start'    fires on work-phase entry
///   - 'bell_end'      fires on complete-phase entry
///   - 'whistle_long'  fires on rest-phase entry
///
/// Priority (enforced by the real AudioService in a later step):
///   bell_end > bell_start > whistle_long > wood_clack
class AudioService {
  /// Fire-and-forget cue trigger. In the stub, this is a no-op — the engine's
  /// behaviour is driven entirely by its own time math, not by audio state.
  /// Tests use a FakeAudioService subclass that records calls for assertion.
  Future<void> play(String cueName) async {}

  /// Release underlying audio resources. No-op in the stub.
  Future<void> dispose() async {}
}
