import 'package:eight_count/features/video/services/permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

/// Records call-counts so request-vs-check assertions are easy.
class _FakeAdapter implements PermissionPlatformAdapter {
  _FakeAdapter({
    required this.cameraInitial,
    required this.microphoneInitial,
    Map<Permission, PermissionStatus>? requestResult,
    this.openSettingsResult = true,
  }) : _requestResult = requestResult;

  PermissionStatus cameraInitial;
  PermissionStatus microphoneInitial;
  final Map<Permission, PermissionStatus>? _requestResult;
  final bool openSettingsResult;

  int cameraStatusCalls = 0;
  int microphoneStatusCalls = 0;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<PermissionStatus> cameraStatus() async {
    cameraStatusCalls++;
    return cameraInitial;
  }

  @override
  Future<PermissionStatus> microphoneStatus() async {
    microphoneStatusCalls++;
    return microphoneInitial;
  }

  @override
  Future<Map<Permission, PermissionStatus>>
      requestCameraAndMicrophone() async {
    requestCalls++;
    final result = _requestResult ??
        <Permission, PermissionStatus>{
          Permission.camera: cameraInitial,
          Permission.microphone: microphoneInitial,
        };
    // Mirror real behavior: post-request the cached statuses
    // typically reflect what the user just chose.
    cameraInitial =
        result[Permission.camera] ?? cameraInitial;
    microphoneInitial =
        result[Permission.microphone] ?? microphoneInitial;
    return result;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return openSettingsResult;
  }
}

void main() {
  group('PermissionService.check', () {
    test('returns granted/granted when both granted', () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.granted,
        microphoneInitial: PermissionStatus.granted,
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.check();
      expect(state.camera, VideoPermissionStatus.granted);
      expect(state.microphone, VideoPermissionStatus.granted);
      expect(state.allGranted, isTrue);
      expect(state.anyPermanentlyDenied, isFalse);
      // check() must NEVER trigger a request.
      expect(adapter.requestCalls, 0);
    });

    test('returns denied/granted with allGranted=false', () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.denied,
        microphoneInitial: PermissionStatus.granted,
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.check();
      expect(state.camera, VideoPermissionStatus.denied);
      expect(state.microphone, VideoPermissionStatus.granted);
      expect(state.allGranted, isFalse);
      expect(state.anyPermanentlyDenied, isFalse);
    });
  });

  group('PermissionService.request', () {
    test('both permanently denied → anyPermanentlyDenied=true', () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.denied,
        microphoneInitial: PermissionStatus.denied,
        requestResult: <Permission, PermissionStatus>{
          Permission.camera: PermissionStatus.permanentlyDenied,
          Permission.microphone: PermissionStatus.permanentlyDenied,
        },
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.request();
      expect(state.allGranted, isFalse);
      expect(state.anyPermanentlyDenied, isTrue);
      expect(adapter.requestCalls, 1);
    });

    test('limited maps to granted (iOS Photos edge case)', () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.denied,
        microphoneInitial: PermissionStatus.denied,
        requestResult: <Permission, PermissionStatus>{
          Permission.camera: PermissionStatus.limited,
          Permission.microphone: PermissionStatus.granted,
        },
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.request();
      expect(state.camera, VideoPermissionStatus.granted);
      expect(state.microphone, VideoPermissionStatus.granted);
      expect(state.allGranted, isTrue);
    });

    test('null entry in request map → unknown, no crash', () async {
      // Simulate an upstream platform that omitted one permission
      // from the result map (defensive; not seen in practice).
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.denied,
        microphoneInitial: PermissionStatus.denied,
        requestResult: <Permission, PermissionStatus>{
          Permission.camera: PermissionStatus.granted,
          // microphone intentionally absent
        },
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.request();
      expect(state.camera, VideoPermissionStatus.granted);
      expect(state.microphone, VideoPermissionStatus.unknown);
      expect(state.allGranted, isFalse);
    });

    test('restricted maps to restricted (iOS parental-controls case)',
        () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.restricted,
        microphoneInitial: PermissionStatus.granted,
      );
      final service = PermissionService(adapter: adapter);
      final state = await service.check();
      expect(state.camera, VideoPermissionStatus.restricted);
      expect(state.allGranted, isFalse);
      expect(state.anyPermanentlyDenied, isFalse);
    });
  });

  group('PermissionService.openSettings', () {
    test('forwards adapter result and increments call count', () async {
      final adapter = _FakeAdapter(
        cameraInitial: PermissionStatus.permanentlyDenied,
        microphoneInitial: PermissionStatus.permanentlyDenied,
        openSettingsResult: true,
      );
      final service = PermissionService(adapter: adapter);
      final result = await service.openSettings();
      expect(result, isTrue);
      expect(adapter.openSettingsCalls, 1);
    });
  });

  group('VideoPermissionState equality', () {
    test('structural ==/hashCode', () {
      const a = VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.denied,
      );
      const b = VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.denied,
      );
      const c = VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.granted,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });
}
