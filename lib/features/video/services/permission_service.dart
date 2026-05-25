import 'package:permission_handler/permission_handler.dart';

/// Day 2+ task: VideoCaptureService must handle CameraException from
/// permission revocation mid-stream by stopping cleanly and surfacing
/// to user.
//
// Day 1 surface: read-only checks + a single batched request, plus an
// app-settings escape hatch. No CameraController, no recording, no
// scheduler.

/// Project-level abstraction over [PermissionStatus] so the rest of
/// the app never imports `permission_handler` types directly.
enum VideoPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

/// Snapshot of the camera + microphone permission states relevant to
/// video capture. Equality is structural so tests (and `setState`
/// equality checks in widgets) can compare instances cheaply.
class VideoPermissionState {
  const VideoPermissionState({
    required this.camera,
    required this.microphone,
  });

  final VideoPermissionStatus camera;
  final VideoPermissionStatus microphone;

  bool get allGranted =>
      camera == VideoPermissionStatus.granted &&
      microphone == VideoPermissionStatus.granted;

  bool get anyPermanentlyDenied =>
      camera == VideoPermissionStatus.permanentlyDenied ||
      microphone == VideoPermissionStatus.permanentlyDenied;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VideoPermissionState &&
          other.camera == camera &&
          other.microphone == microphone);

  @override
  int get hashCode => Object.hash(camera, microphone);
}

/// Thin seam over `permission_handler` so [PermissionService] can be
/// unit-tested without the platform plugin. Production code uses
/// [DefaultPermissionPlatformAdapter]; tests inject a fake.
abstract class PermissionPlatformAdapter {
  Future<PermissionStatus> cameraStatus();
  Future<PermissionStatus> microphoneStatus();

  /// Single batched request — produces one OS dialog sequence on each
  /// platform. The returned `Map<Permission, PermissionStatus>` mirrors
  /// the upstream API shape so callers can read each permission
  /// independently.
  Future<Map<Permission, PermissionStatus>> requestCameraAndMicrophone();

  /// Wraps [openAppSettings]. Returns the bool that upstream returns
  /// (true = the system intent succeeded, not "user granted").
  Future<bool> openSettings();
}

class DefaultPermissionPlatformAdapter implements PermissionPlatformAdapter {
  const DefaultPermissionPlatformAdapter();

  @override
  Future<PermissionStatus> cameraStatus() => Permission.camera.status;

  @override
  Future<PermissionStatus> microphoneStatus() =>
      Permission.microphone.status;

  @override
  Future<Map<Permission, PermissionStatus>>
      requestCameraAndMicrophone() async =>
          <Permission>[Permission.camera, Permission.microphone].request();

  @override
  Future<bool> openSettings() => openAppSettings();
}

/// Project-facing permission API. Owns all `permission_handler`
/// interaction; callers see only [VideoPermissionState] /
/// [VideoPermissionStatus] and never the upstream types.
class PermissionService {
  PermissionService({PermissionPlatformAdapter? adapter})
      : _adapter = adapter ?? const DefaultPermissionPlatformAdapter();

  final PermissionPlatformAdapter _adapter;

  /// Read-only — never triggers a dialog. Used on screen entry to
  /// reflect current OS state in UI.
  Future<VideoPermissionState> check() async {
    final results = await Future.wait(<Future<PermissionStatus>>[
      _adapter.cameraStatus(),
      _adapter.microphoneStatus(),
    ]);
    return VideoPermissionState(
      camera: _map(results[0]),
      microphone: _map(results[1]),
    );
  }

  /// Triggers a single OS dialog sequence (one per permission, but
  /// chained without a re-prompt of the education sheet).
  Future<VideoPermissionState> request() async {
    final result = await _adapter.requestCameraAndMicrophone();
    return VideoPermissionState(
      camera: _map(result[Permission.camera]),
      microphone: _map(result[Permission.microphone]),
    );
  }

  /// Opens the app's settings page so the user can flip a
  /// permanently-denied permission back to granted.
  Future<bool> openSettings() => _adapter.openSettings();

  /// Maps `permission_handler` statuses to project-internal ones.
  /// `.limited` is folded into `.granted` (iOS Photos edge case;
  /// inert here but consistent for future Photos work).
  /// Unknown / unmapped statuses fall through to [VideoPermissionStatus.unknown]
  /// rather than crashing.
  static VideoPermissionStatus _map(PermissionStatus? status) {
    if (status == null) return VideoPermissionStatus.unknown;
    if (status.isGranted || status.isLimited) {
      return VideoPermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return VideoPermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return VideoPermissionStatus.restricted;
    }
    if (status.isDenied) {
      return VideoPermissionStatus.denied;
    }
    return VideoPermissionStatus.unknown;
  }
}
