import 'package:flutter/foundation.dart';

/// Front- or back-facing camera selection for clip capture.
enum CameraDirection { front, back }

/// Capture resolution preset. Drives the [ResolutionPreset] passed to
/// the camera plugin when recording starts.
enum VideoResolution { low720, high1080 }

/// Immutable user preferences for the Video Pack feature. Persisted via
/// [VideoSettingsService] under SharedPreferences key `video_settings_v1`.
///
/// All fields default to a conservative, opt-in state: [videoCaptureEnabled]
/// is false until the user flips the master switch in Settings → Video.
/// No camera hardware is touched while this flag is false.
@immutable
class VideoSettings {
  const VideoSettings({
    required this.videoCaptureEnabled,
    required this.clipDurationSeconds,
    required this.cameraDirection,
    required this.captureTimestampsRemaining,
    required this.clipsPerRound,
    required this.resolution,
    required this.aiAutoPickEnabled,
  });

  /// Default settings — opt-in (capture disabled), back camera, 30s
  /// clips at 720p, AI auto-pick on, no timestamps configured yet.
  factory VideoSettings.defaults() => const VideoSettings(
        videoCaptureEnabled: false,
        clipDurationSeconds: 30,
        cameraDirection: CameraDirection.back,
        captureTimestampsRemaining: <int>[],
        clipsPerRound: 1,
        resolution: VideoResolution.low720,
        aiAutoPickEnabled: true,
      );

  factory VideoSettings.fromJson(Map<String, dynamic> json) => VideoSettings(
        videoCaptureEnabled: json['videoCaptureEnabled'] as bool? ?? false,
        clipDurationSeconds: json['clipDurationSeconds'] as int? ?? 30,
        cameraDirection: _decodeCameraDirection(
          json['cameraDirection'] as String?,
        ),
        captureTimestampsRemaining:
            (json['captureTimestampsRemaining'] as List<dynamic>?)
                    ?.map((e) => e as int)
                    .toList() ??
                const <int>[],
        clipsPerRound: json['clipsPerRound'] as int? ?? 1,
        resolution: _decodeResolution(json['resolution'] as String?),
        aiAutoPickEnabled: json['aiAutoPickEnabled'] as bool? ?? true,
      );

  /// Master switch — when false, the engine never spins up the camera
  /// or requests permissions. Every other field is inert until this is
  /// true.
  final bool videoCaptureEnabled;

  /// Per-clip duration in seconds. Allowed values: 20 or 30.
  final int clipDurationSeconds;

  final CameraDirection cameraDirection;

  /// Seconds-remaining-in-round at which a clip should fire. Element
  /// values are seconds remaining (e.g., 150 = 2:30 remaining). Empty
  /// list means no clips configured. List ordering is not significant
  /// — the engine treats this as a set.
  final List<int> captureTimestampsRemaining;

  /// Maximum clips to record per round. 1, 2, or 3.
  final int clipsPerRound;

  final VideoResolution resolution;

  /// When true, post-workout review surfaces the AI's top picks rather
  /// than every clip. The selection algorithm itself is wired in a
  /// later stage.
  final bool aiAutoPickEnabled;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'videoCaptureEnabled': videoCaptureEnabled,
        'clipDurationSeconds': clipDurationSeconds,
        'cameraDirection': cameraDirection.name,
        'captureTimestampsRemaining': captureTimestampsRemaining,
        'clipsPerRound': clipsPerRound,
        'resolution': resolution.name,
        'aiAutoPickEnabled': aiAutoPickEnabled,
      };

  VideoSettings copyWith({
    bool? videoCaptureEnabled,
    int? clipDurationSeconds,
    CameraDirection? cameraDirection,
    List<int>? captureTimestampsRemaining,
    int? clipsPerRound,
    VideoResolution? resolution,
    bool? aiAutoPickEnabled,
  }) {
    return VideoSettings(
      videoCaptureEnabled: videoCaptureEnabled ?? this.videoCaptureEnabled,
      clipDurationSeconds: clipDurationSeconds ?? this.clipDurationSeconds,
      cameraDirection: cameraDirection ?? this.cameraDirection,
      captureTimestampsRemaining:
          captureTimestampsRemaining ?? this.captureTimestampsRemaining,
      clipsPerRound: clipsPerRound ?? this.clipsPerRound,
      resolution: resolution ?? this.resolution,
      aiAutoPickEnabled: aiAutoPickEnabled ?? this.aiAutoPickEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoSettings &&
        other.videoCaptureEnabled == videoCaptureEnabled &&
        other.clipDurationSeconds == clipDurationSeconds &&
        other.cameraDirection == cameraDirection &&
        listEquals(
          other.captureTimestampsRemaining,
          captureTimestampsRemaining,
        ) &&
        other.clipsPerRound == clipsPerRound &&
        other.resolution == resolution &&
        other.aiAutoPickEnabled == aiAutoPickEnabled;
  }

  @override
  int get hashCode => Object.hash(
        videoCaptureEnabled,
        clipDurationSeconds,
        cameraDirection,
        Object.hashAll(captureTimestampsRemaining),
        clipsPerRound,
        resolution,
        aiAutoPickEnabled,
      );

  static CameraDirection _decodeCameraDirection(String? raw) {
    switch (raw) {
      case 'front':
        return CameraDirection.front;
      case 'back':
      default:
        return CameraDirection.back;
    }
  }

  static VideoResolution _decodeResolution(String? raw) {
    switch (raw) {
      case 'high1080':
        return VideoResolution.high1080;
      case 'low720':
      default:
        return VideoResolution.low720;
    }
  }
}
