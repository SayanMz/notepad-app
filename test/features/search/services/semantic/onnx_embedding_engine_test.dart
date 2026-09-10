import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/semantic/onnx_embedding_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('onnx_engine_test_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
            case 'getTemporaryDirectory':
              return tempDir.path;
            default:
              return null;
          }
        });
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('OnnxEmbeddingEngine', () {
    test(
      'isModelAvailable returns false when local file and asset are both missing',
      () async {
        // Intercept asset loading to simulate the production scenario where the model is not bundled
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', (message) async {
              return null; // Simulates missing asset / FlutterError
            });

        final available = await OnnxEmbeddingEngine.isModelAvailable();
        expect(available, isFalse);

        // Restore default asset handler for subsequent tests
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMessageHandler('flutter/assets', null);
      },
    );

    test(
      'getLocalModelFile returns File reference pointing to model path',
      () async {
        final file = await OnnxEmbeddingEngine.getLocalModelFile();
        expect(file, isA<File>());
        expect(file.path.endsWith('all-minilm-l6-v2-int8.onnx'), isTrue);
      },
    );
  });
}
