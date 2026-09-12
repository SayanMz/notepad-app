import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/model_download_service.dart';

void main() {
  group('ModelVerifier', () {
    test('expectedModelSha256 is non-empty 64-character hex string', () {
      expect(ModelVerifier.expectedModelSha256.length, equals(64));
    });

    test('verifyModelIntegrity returns false for non-existent file', () async {
      final nonExistent = File('/tmp/non_existent_model_file_xyz_123.onnx');
      final isValid = await ModelVerifier.verifyModelIntegrity(nonExistent);
      expect(isValid, isFalse);
    });

    test('verifyModelIntegrity returns false for corrupted/empty file', () async {
      final tempDir = await Directory.systemTemp.createTemp('model_verifier_test_');
      final corruptFile = File('${tempDir.path}/corrupt.onnx');
      await corruptFile.writeAsString('corrupted content');

      final isValid = await ModelVerifier.verifyModelIntegrity(corruptFile);
      expect(isValid, isFalse);

      await tempDir.delete(recursive: true);
    });
  });

  group('ModelDownloadService', () {
    test('progressNotifier initial state is 0.0', () {
      expect(ModelDownloadService.progressNotifier.value, 0.0);
    });

    test('statusNotifier initial state is idle', () {
      expect(ModelDownloadService.statusNotifier.value, ModelDownloadState.idle);
    });

    test('cancelDownload resets downloading flags and progress', () async {
      ModelDownloadService.progressNotifier.value = 0.5;
      ModelDownloadService.statusNotifier.value = ModelDownloadState.downloading;
      
      await ModelDownloadService.cancelDownload();
      
      expect(ModelDownloadService.progressNotifier.value, 0.0);
      expect(ModelDownloadService.statusNotifier.value, ModelDownloadState.idle);
    });
  });
}