import 'package:eight_count/features/video/screens/video_permission_education_screen.dart';
import 'package:eight_count/features/video/services/permission_service.dart';
import 'package:eight_count/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

class _StubPermissionService implements PermissionService {
  _StubPermissionService(this._next);

  final VideoPermissionState _next;
  int requestCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<VideoPermissionState> check() async => _next;

  @override
  Future<VideoPermissionState> request() async {
    requestCalls++;
    return _next;
  }

  @override
  Future<bool> openSettings() async {
    openSettingsCalls++;
    return true;
  }
}

Widget _wrap(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: child,
  );
}

void main() {
  testWidgets('renders title, body, both bullets, both buttons (EN)',
      (tester) async {
    final stub = _StubPermissionService(
      const VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.granted,
      ),
    );
    await tester.pumpWidget(
      _wrap(VideoPermissionEducationScreen(permissionService: stub)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Capture Your Workout'), findsOneWidget);
    expect(
      find.textContaining('records short clips during your rounds'),
      findsOneWidget,
    );
    expect(find.text('Camera — to record your rounds'), findsOneWidget);
    expect(
      find.text('Microphone — to capture audio cues and impact'),
      findsOneWidget,
    );
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
  });

  testWidgets('Continue tap invokes request() exactly once', (tester) async {
    final stub = _StubPermissionService(
      const VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.granted,
      ),
    );
    await tester.pumpWidget(
      _wrap(VideoPermissionEducationScreen(permissionService: stub)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(stub.requestCalls, 1);
  });

  testWidgets('Not Now pops with null', (tester) async {
    final stub = _StubPermissionService(
      const VideoPermissionState(
        camera: VideoPermissionStatus.granted,
        microphone: VideoPermissionStatus.granted,
      ),
    );

    await tester.pumpWidget(_wrap(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.of(context).push<
                    VideoPermissionState?>(
                  MaterialPageRoute<VideoPermissionState?>(
                    builder: (_) => VideoPermissionEducationScreen(
                      permissionService: stub,
                    ),
                  ),
                );
                expect(result, isNull);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    // Education screen should be gone.
    expect(find.text('Capture Your Workout'), findsNothing);
    expect(stub.requestCalls, 0);
  });

  testWidgets('permanent denial shows SnackBar with Open Settings action',
      (tester) async {
    final stub = _StubPermissionService(
      const VideoPermissionState(
        camera: VideoPermissionStatus.permanentlyDenied,
        microphone: VideoPermissionStatus.permanentlyDenied,
      ),
    );
    await tester.pumpWidget(
      _wrap(VideoPermissionEducationScreen(permissionService: stub)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    // Pump enough to settle the SnackBar's slide-in animation.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 250));

    expect(
      find.text('Enable camera and mic in Settings to record.'),
      findsOneWidget,
    );
    expect(find.text('Open Settings'), findsOneWidget);

    // Tap the Open Settings action and verify the service is called.
    await tester.tap(find.text('Open Settings'));
    await tester.pump();
    expect(stub.openSettingsCalls, 1);
  });
}
