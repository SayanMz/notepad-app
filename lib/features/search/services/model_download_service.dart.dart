import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// Handles background downloading and SHA-256 verification for local AI model files.
class ModelDownloadService {
  static const MethodChannel _channel = MethodChannel(
    'com.notepad.app/native_downloader',
  );
  static final ValueNotifier<double?> downloadProgressNotifier = ValueNotifier(
    null,
  );
  static final ValueNotifier<bool> isModelDownloaded = ValueNotifier<bool>(
    false,
  );
  static VoidCallback? onModelDownloaded;

  static Timer? _pollTimer;
  static bool _isDownloading = false;
  static const String _subPath = 'models/all-minilm-l6-v2-int8.onnx';

  static const String _modelUrl =
      'https://github.com/SayanMz/notepad-app/releases/download/2.5.0/all-minilm-l6-v2-int8.onnx';

  static void init() {}

  static Future<bool> startBackgroundDownload() async {
    if (_isDownloading || (_pollTimer != null && _pollTimer!.isActive)) {
      return true;
    }
    _isDownloading = true;

    try {
      final baseDir =
          await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();

      // Hand off large ONNX binary to native Android DownloadManager
      final dynamic downloadId = await _channel.invokeMethod(
        'enqueueDownload',
        {'url': _modelUrl, 'subPath': _subPath, 'title': 'AI Search Model'},
      );

      if (downloadId == null || downloadId == -1) {
        _isDownloading = false;
        return false;
      }

      downloadProgressNotifier.value = 0.01;

      _pollTimer?.cancel();
      _pollTimer = Timer.periodic(const Duration(milliseconds: 500), (
        timer,
      ) async {
        final dynamic result = await _channel.invokeMethod(
          'getDownloadProgress',
          {'subPath': _subPath},
        );

        if (result is Map) {
          final status = result['status'] as String?;
          final progress = (result['progress'] as num?)?.toDouble() ?? 0.0;

          if (status == 'RUNNING' || status == 'PENDING') {
            downloadProgressNotifier.value = progress.clamp(0.0, 1.0);
          } else if (status == 'SUCCESS') {
            downloadProgressNotifier.value = null;
            _isDownloading = false;
            timer.cancel();

            final downloadedModelFile = File(join(baseDir.path, _subPath));
            final isValid = await ModelVerifier.verifyModelIntegrity(
              downloadedModelFile,
            );

            if (isValid) {
              onModelDownloaded?.call();
            } else {
              debugPrint(
                'ModelDownloadService: Hash mismatch. Deleting model file...',
              );
              showErrorSnackBar(
                'Downloaded model file was corrupt. Please download again.',
              );
              try {
                if (downloadedModelFile.existsSync()) {
                  await downloadedModelFile.delete();
                }
              } catch (_) {}
            }
          } else if (status == 'FAILED' || status == 'NOT_FOUND') {
            timer.cancel();
            await cancelDownload();
            showErrorSnackBar(
              'Download failed. Please check your connection and retry.',
            );
          }
        }
      });

      return true;
    } catch (e) {
      debugPrint('Download Error: $e');
      await cancelDownload();
      return false;
    }
  }

  static Future<void> cancelDownload() async {
    _pollTimer?.cancel();
    _pollTimer = null;
    _isDownloading = false;

    downloadProgressNotifier.value = null;

    try {
      await _channel.invokeMethod('cancelDownload', {'subPath': _subPath});
    } catch (_) {}
  }
}

/// Verifies local ONNX model file integrity against expected SHA-256 signatures.
class ModelVerifier {
  static const String expectedModelSha256 =
      'afdb6f1a0e45b715d0bb9b11772f032c399babd23bfc31fed1c170afc848bdb1';

  static Future<bool> verifyModelIntegrity(File modelFile) async {
    if (!modelFile.existsSync()) return false;
    return compute(_calculateFileHash, modelFile.path);
  }

  static Future<bool> _calculateFileHash(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;

    try {
      final digest = await sha256.bind(file.openRead()).first;
      return digest.toString().toLowerCase() ==
          expectedModelSha256.toLowerCase();
    } catch (e) {
      debugPrint('Model hash verification error: $e');
      return false;
    }
  }
}
