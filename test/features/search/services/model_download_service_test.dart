import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:notepad/features/search/services/model_download_service.dart.dart';

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
    test('downloadProgressNotifier initial state is null', () {
      expect(ModelDownloadService.downloadProgressNotifier.value, isNull);
    });

    test('isModelDownloaded initial state is false', () {
      expect(ModelDownloadService.isModelDownloaded.value, isFalse);
    });

    test('cancelDownload resets downloading flags and progress', () async {
      ModelDownloadService.downloadProgressNotifier.value = 0.5;
      await ModelDownloadService.cancelDownload();
      expect(ModelDownloadService.downloadProgressNotifier.value, isNull);
    });
  });
}