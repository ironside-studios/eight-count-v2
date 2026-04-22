import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/core/services/audio_service.dart';

/// Test subclass — overrides every hook that touches `just_audio`. The queue
/// and priority state machine runs against in-memory recorders.
class _TestableAudioService extends AudioService {
  final List<String> starts = <String>[];
  final List<String> stops = <String>[];
  final Map<String, Duration> _remaining = <String, Duration>{};

  /// Sets what [remainingFor] will return for [cue] on subsequent calls.
  void setRemaining(String cue, Duration value) {
    _remaining[cue] = value;
  }

  /// Simulates the currently-playing cue reaching its natural end.
  void completeCue(String cue) {
    handlePlaybackCompleted(cue);
  }

  @override
  Future<void> loadPlayers() async {
    // Intentional no-op: the real impl calls into just_audio which needs a
    // platform channel. Tests drive state via the overridden hooks below.
  }

  @override
  Future<void> startPlayback(String cueName) async {
    starts.add(cueName);
  }

  @override
  Future<void> stopPlayback(String cueName) async {
    stops.add(cueName);
  }

  @override
  Duration remainingFor(String cueName) =>
      _remaining[cueName] ?? Duration.zero;
}

void main() {
  late _TestableAudioService audio;

  setUp(() async {
    audio = _TestableAudioService();
    await audio.init();
  });

  tearDown(() async {
    await audio.dispose();
  });

  test('play() with unknown cueName throws ArgumentError', () {
    expect(() => audio.play('unknown_cue'), throwsArgumentError);
  });

  test('play() with no current cue plays immediately and sets currentCue',
      () async {
    await audio.play('bell_start');
    await audio.settle();

    expect(audio.currentCue, 'bell_start');
    expect(audio.starts, <String>['bell_start']);
    expect(audio.stops, isEmpty);
    expect(audio.queuedCue, isNull);
  });

  test('play() with >200ms remaining stops current and plays new', () async {
    // Same cue (same priority) so we take the queue-rule path, not priority.
    await audio.play('wood_clack');
    await audio.settle();
    audio.setRemaining('wood_clack', const Duration(milliseconds: 500));

    await audio.play('wood_clack');
    await audio.settle();

    expect(audio.stops, <String>['wood_clack']);
    expect(audio.starts, <String>['wood_clack', 'wood_clack']);
    expect(audio.currentCue, 'wood_clack');
    expect(audio.queuedCue, isNull);
  });

  test('play() with ≤200ms remaining queues new cue', () async {
    await audio.play('bell_start');
    await audio.settle();
    audio.setRemaining('bell_start', const Duration(milliseconds: 100));

    await audio.play('bell_start');
    await audio.settle();

    expect(audio.starts, <String>['bell_start']);
    expect(audio.stops, isEmpty);
    expect(audio.currentCue, 'bell_start');
    expect(audio.queuedCue, 'bell_start');
  });

  group('priority preemption — higher cue plays immediately, skipping 200ms check',
      () {
    test('bell_end preempts wood_clack even with plenty of time remaining',
        () async {
      await audio.play('wood_clack');
      await audio.settle();
      audio.setRemaining('wood_clack', const Duration(seconds: 1));

      await audio.play('bell_end');
      await audio.settle();

      expect(audio.stops, <String>['wood_clack']);
      expect(audio.starts, <String>['wood_clack', 'bell_end']);
      expect(audio.currentCue, 'bell_end');
      expect(audio.queuedCue, isNull);
    });

    test('bell_start preempts wood_clack', () async {
      await audio.play('wood_clack');
      await audio.settle();
      audio.setRemaining('wood_clack', const Duration(seconds: 1));

      await audio.play('bell_start');
      await audio.settle();

      expect(audio.stops, <String>['wood_clack']);
      expect(audio.starts, <String>['wood_clack', 'bell_start']);
      expect(audio.currentCue, 'bell_start');
    });

    test('whistle_long preempts wood_clack', () async {
      await audio.play('wood_clack');
      await audio.settle();
      audio.setRemaining('wood_clack', const Duration(seconds: 1));

      await audio.play('whistle_long');
      await audio.settle();

      expect(audio.stops, <String>['wood_clack']);
      expect(audio.starts, <String>['wood_clack', 'whistle_long']);
      expect(audio.currentCue, 'whistle_long');
    });
  });

  test('lower-priority cue during higher-priority follows queue rule (no preempt)',
      () async {
    await audio.play('bell_end');
    await audio.settle();
    // ≤200ms keeps us in the queue-not-stop path so we're testing "no
    // preempt" without also exercising the stop-and-play branch.
    audio.setRemaining('bell_end', const Duration(milliseconds: 100));

    await audio.play('wood_clack');
    await audio.settle();

    expect(audio.stops, isEmpty);
    expect(audio.starts, <String>['bell_end']);
    expect(audio.currentCue, 'bell_end');
    expect(audio.queuedCue, 'wood_clack');
  });

  test('two queued cues in rapid succession: last-write-wins', () async {
    await audio.play('bell_end');
    await audio.settle();
    audio.setRemaining('bell_end', const Duration(milliseconds: 100));

    // Fire two queue-bound plays back-to-back. Both are lower priority than
    // bell_end, so neither preempts; the second replaces the first in queue.
    final Future<void> first = audio.play('wood_clack');
    final Future<void> second = audio.play('whistle_long');
    await Future.wait(<Future<void>>[first, second]);
    await audio.settle();

    expect(audio.queuedCue, 'whistle_long');
    expect(audio.currentCue, 'bell_end');
  });

  test('queued cue is promoted when current cue completes naturally', () async {
    await audio.play('bell_end');
    await audio.settle();
    audio.setRemaining('bell_end', const Duration(milliseconds: 100));
    await audio.play('wood_clack');
    await audio.settle();
    expect(audio.queuedCue, 'wood_clack');

    // Simulate bell_end finishing on its own.
    audio.completeCue('bell_end');
    await audio.settle();

    expect(audio.currentCue, 'wood_clack');
    expect(audio.queuedCue, isNull);
    expect(audio.starts, <String>['bell_end', 'wood_clack']);
  });

  test('dispose() cancels queued cue and stops current', () async {
    await audio.play('bell_end');
    await audio.settle();
    audio.setRemaining('bell_end', const Duration(milliseconds: 100));
    await audio.play('wood_clack');
    await audio.settle();
    expect(audio.queuedCue, 'wood_clack');
    expect(audio.currentCue, 'bell_end');

    await audio.dispose();

    expect(audio.currentCue, isNull);
    expect(audio.queuedCue, isNull);
    expect(audio.stops, contains('bell_end'));
  });
}
