import 'package:flutter_test/flutter_test.dart';
import 'package:eight_count/core/services/audio_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AudioService lifecycle', () {
    test('stopAll cancels in-flight chain and resets state', () async {
      final service = AudioService.instance;

      service.play('bell_start');
      service.play('wood_clack');
      service.play('bell_end');

      await service.stopAll();

      expect(service.currentCue, isNull);
      expect(service.queuedCue, isNull);
    });

    test('service is reusable after stopAll', () async {
      final service = AudioService.instance;
      await service.stopAll();

      expect(() => service.play('bell_start'), returnsNormally);
    });
  });
}
