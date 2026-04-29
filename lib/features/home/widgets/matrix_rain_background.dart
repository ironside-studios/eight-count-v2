import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/navigation/route_observer.dart';
import 'matrix_rain_painter.dart';

/// Falling-character home-screen background. 30-50 streams of "8COUNT"
/// chars cascade down the screen with a Matrix-style 3D light-source
/// effect (bright gold heads, fading amber trails). A static "8COUNT"
/// bleed-through layer sits at upper-third opacity 12%; characters
/// brighten when they cross over it.
///
/// Lifecycle:
///   - Pauses ticker when navigating away (RouteAware push/pop chains).
///   - Pauses ticker when app backgrounds (AppLifecycleState.paused).
///   - Resumes cleanly when home becomes the current route again.
///
/// Performance: single Ticker + single CustomPaint, repaint signal is a
/// `ValueNotifier<int>` frame counter so paint runs without a full
/// widget rebuild on each frame.
class MatrixRainBackground extends StatefulWidget {
  const MatrixRainBackground({
    super.key,
    this.streamCount = 40,
    this.speedMultiplier = 1.0,
    this.showBleedThrough = true,
  });

  /// Number of concurrent falling streams. Locked range 30-50 in
  /// production; debug slider exposes 15-100 for visual tuning.
  final int streamCount;

  /// Multiplier on the per-stream falling speed. 1.0 = canonical;
  /// debug slider exposes 0.5-2.0.
  final double speedMultiplier;

  /// When false, suppresses the static "8COUNT" bleed-through layer
  /// (and its per-character brightening). Debug-toggle only.
  final bool showBleedThrough;

  @override
  State<MatrixRainBackground> createState() => _MatrixRainBackgroundState();
}

class _MatrixRainBackgroundState extends State<MatrixRainBackground>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        RouteAware {
  // --- Animation/state ---
  late final Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  final ValueNotifier<int> _frameCounter = ValueNotifier<int>(0);

  // --- Stream pool ---
  final math.Random _rng = math.Random();
  final List<RainStream> _streams = <RainStream>[];

  // --- Layout-derived state ---
  Size? _lastSize;
  ({TextPainter painter, Rect rect})? _bleedThrough;

  // --- Debug overlay state (kDebugMode only) ---
  late int _debugStreamCount;
  late double _debugSpeedMul;
  late bool _debugShowBleed;
  bool _debugOverlayCollapsed = false;

  // --- Route subscription bookkeeping ---
  PageRoute<dynamic>? _subscribedRoute;
  bool _pausedByLifecycle = false;
  bool _pausedByRoute = false;

  @override
  void initState() {
    super.initState();
    _debugStreamCount = widget.streamCount;
    _debugSpeedMul = widget.speedMultiplier;
    _debugShowBleed = widget.showBleedThrough;

    WidgetsBinding.instance.addObserver(this);
    _ticker = createTicker(_onTick);
    // Skip ticker startup under test bindings so existing widget tests
    // that use pumpAndSettle() don't hang on the perpetual frame
    // requests. The Flutter test framework reports its binding type as
    // TestWidgetsFlutterBinding (or a subclass); production app uses
    // WidgetsFlutterBinding. The matrix-rain unit tests pump fixed
    // durations and don't depend on the ticker firing — see
    // test/widgets/matrix_rain_background_test.dart.
    if (!_isUnderTestBinding()) {
      _ticker.start();
    }
  }

  bool _isUnderTestBinding() {
    return WidgetsBinding.instance.runtimeType
        .toString()
        .contains('Test');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modal = ModalRoute.of(context);
    if (modal is PageRoute<dynamic> && modal != _subscribedRoute) {
      if (_subscribedRoute != null) {
        routeObserver.unsubscribe(this);
      }
      _subscribedRoute = modal;
      routeObserver.subscribe(this, modal);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _frameCounter.dispose();
    super.dispose();
  }

  // --- RouteAware ---
  @override
  void didPushNext() {
    // Another route was pushed on top of this one; pause.
    _pausedByRoute = true;
    _ticker.stop();
  }

  @override
  void didPopNext() {
    // We're back to being the current route; resume.
    _pausedByRoute = false;
    if (!_pausedByLifecycle && !_isUnderTestBinding()) {
      _lastTickElapsed = Duration.zero; // avoid catch-up jump
      _ticker.start();
    }
  }

  @override
  void didPush() {
    // Initial push as the current route — ticker started in initState.
  }

  @override
  void didPop() {
    _pausedByRoute = true;
    _ticker.stop();
  }

  // --- AppLifecycleState ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pausedByLifecycle = true;
      if (_ticker.isActive) _ticker.stop();
    } else if (state == AppLifecycleState.resumed) {
      _pausedByLifecycle = false;
      if (!_pausedByRoute &&
          !_ticker.isActive &&
          !_isUnderTestBinding()) {
        _lastTickElapsed = Duration.zero; // avoid catch-up jump
        _ticker.start();
      }
    }
  }

  // --- Tick driver ---
  void _onTick(Duration elapsed) {
    final size = _lastSize;
    if (size == null) {
      _lastTickElapsed = elapsed;
      return;
    }

    final double dtMs = (_lastTickElapsed == Duration.zero)
        ? 16.67
        : (elapsed - _lastTickElapsed).inMicroseconds / 1000.0;
    _lastTickElapsed = elapsed;

    final double dtSec = dtMs / 1000.0;
    final double speedMul = kDebugMode ? _debugSpeedMul : widget.speedMultiplier;

    // Update each stream.
    for (int i = 0; i < _streams.length; i++) {
      final s = _streams[i];
      if (s.isFading) {
        s.fadeOutMs += dtMs;
        if (s.fadeOutMs >= 400) {
          // Respawn at top.
          _streams[i] = spawnStream(
            rng: _rng,
            screenWidth: size.width,
            initialHeadY: -22.0 * (8 + _rng.nextInt(7)),
            screenHeight: size.height,
          );
        }
      } else {
        s.headYPx += s.speedPxS * speedMul * dtSec;
        // Once the head has moved off the bottom by enough that the
        // entire trail is below the screen, start fade-out.
        final double trailBottom = s.headYPx;
        final double trailTop = s.headYPx - 22.0 * s.length;
        if (trailTop > size.height) {
          s.fadeOutMs = 1; // start fading
        } else if (trailBottom > size.height + 22.0) {
          s.fadeOutMs = 1;
        }
      }
    }

    _frameCounter.value++;
  }

  // --- Stream pool sync to layout / debug stream count ---
  void _syncPoolToCount(int desired, Size size) {
    while (_streams.length < desired) {
      _streams.add(spawnStream(
        rng: _rng,
        screenWidth: size.width,
        initialHeadY: 0,
        randomInitialY: true,
        screenHeight: size.height,
      ));
    }
    while (_streams.length > desired) {
      _streams.removeLast();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Recompute bleed-through layer + populate pool on size changes.
        if (_lastSize == null || _lastSize != size) {
          _lastSize = size;
          _bleedThrough = buildBleedThrough(
            screenWidth: size.width,
            screenHeight: size.height,
          );
          _syncPoolToCount(
            kDebugMode ? _debugStreamCount : widget.streamCount,
            size,
          );
        } else if (kDebugMode &&
            _streams.length != _debugStreamCount) {
          _syncPoolToCount(_debugStreamCount, size);
        }

        return Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              size: size,
              painter: MatrixRainPainter(
                repaint: _frameCounter,
                streams: _streams,
                bleedThroughText: _bleedThrough,
                bleedThroughEnabled:
                    kDebugMode ? _debugShowBleed : widget.showBleedThrough,
              ),
            ),
            if (kDebugMode)
              Positioned(
                top: 8,
                right: 8,
                child: _DebugTuningOverlay(
                  collapsed: _debugOverlayCollapsed,
                  onToggleCollapsed: () => setState(
                      () => _debugOverlayCollapsed = !_debugOverlayCollapsed),
                  streamCount: _debugStreamCount,
                  speedMul: _debugSpeedMul,
                  showBleed: _debugShowBleed,
                  onStreamCount: (v) =>
                      setState(() => _debugStreamCount = v),
                  onSpeedMul: (v) => setState(() => _debugSpeedMul = v),
                  onShowBleed: (v) => setState(() => _debugShowBleed = v),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Top-right debug tuning panel. Compiled out of release builds via the
/// `if (kDebugMode)` gate at the call site.
class _DebugTuningOverlay extends StatelessWidget {
  const _DebugTuningOverlay({
    required this.collapsed,
    required this.onToggleCollapsed,
    required this.streamCount,
    required this.speedMul,
    required this.showBleed,
    required this.onStreamCount,
    required this.onSpeedMul,
    required this.onShowBleed,
  });

  final bool collapsed;
  final VoidCallback onToggleCollapsed;
  final int streamCount;
  final double speedMul;
  final bool showBleed;
  final ValueChanged<int> onStreamCount;
  final ValueChanged<double> onSpeedMul;
  final ValueChanged<bool> onShowBleed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return GestureDetector(
        onTap: onToggleCollapsed,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            border: Border.all(color: const Color(0x66FFD700)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text(
            'matrix_debug',
            style: TextStyle(color: Color(0xFFFFD700), fontSize: 10),
          ),
        ),
      );
    }
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xCC000000),
        border: Border.all(color: const Color(0x66FFD700)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onToggleCollapsed,
            child: const Text(
              'matrix_debug — tap to collapse',
              style: TextStyle(color: Color(0xFFFFD700), fontSize: 10),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'streams: $streamCount',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Slider(
            value: streamCount.toDouble(),
            min: 15,
            max: 100,
            divisions: 85,
            onChanged: (v) => onStreamCount(v.round()),
          ),
          Text(
            'speed: ${speedMul.toStringAsFixed(2)}x',
            style: const TextStyle(color: Colors.white, fontSize: 10),
          ),
          Slider(
            value: speedMul,
            min: 0.5,
            max: 2.0,
            divisions: 30,
            onChanged: onSpeedMul,
          ),
          Row(
            children: [
              const Text(
                'bleed-through',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
              const Spacer(),
              Switch(value: showBleed, onChanged: onShowBleed),
            ],
          ),
        ],
      ),
    );
  }
}
