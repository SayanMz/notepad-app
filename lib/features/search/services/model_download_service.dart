import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:notepad/core/services/ui_management/scaffold_messenger_notifier.dart';
import 'package:notepad/features/search/services/semantic_search.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

enum ModelDownloadState { idle, downloading, ready }

/// Handles background downloading and SHA-256 verification for local AI model files.
class ModelDownloadService {
  static const MethodChannel _channel = MethodChannel(
    'com.notepad.app/native_downloader',
  );
  static final ValueNotifier<ModelDownloadState> statusNotifier =
      ValueNotifier<ModelDownloadState>(ModelDownloadState.idle);

  static final ValueNotifier<double> progressNotifier = ValueNotifier<double>(
    0.0,
  );
  static Future<void> Function()? onModelDownloaded;

  static Timer? _pollTimer;
  static const String _subPath = 'models/bge-small-en-v1.5.onnx';

  static const String _modelUrl =
      'https://github.com/SayanMz/notepad-app/releases/download/2.5.0/bge-small-en-v1.5.onnx';

  static Future<void> init() async {
    final available = await SemanticSearchService.isModelAvailable();
    if (available) {
      statusNotifier.value = ModelDownloadState.ready;
    }
  }

  static Future<bool> _hasActiveInternet() async {
    try {
      // 1. Resolve host
      final addresses = await InternetAddress.lookup(
        'github.com',
      ).timeout(const Duration(seconds: 2));
      if (addresses.isEmpty || addresses.first.rawAddress.isEmpty) return false;

      // 2. Actually open a raw TCP socket to verify outbound connectivity
      final socket = await Socket.connect(
        addresses.first,
        443,
        timeout: const Duration(seconds: 2),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> startBackgroundDownload() async {
    if (statusNotifier.value == ModelDownloadState.downloading) {
      return true;
    }

    // Pre-flight check: Fail fast if offline
    if (!await _hasActiveInternet()) {
      return false;
    }

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
        return false;
      }

      statusNotifier.value = ModelDownloadState.downloading;
      progressNotifier.value = 0.01;

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
            progressNotifier.value = progress.clamp(0.0, 1.0);
          } else if (status == 'SUCCESS') {
            timer.cancel();
            progressNotifier.value = 1.0;

            final downloadedModelFile = File(join(baseDir.path, _subPath));
            final isValid = await ModelVerifier.verifyModelIntegrity(
              downloadedModelFile,
            );

            if (isValid) {
              if (onModelDownloaded != null) {
                await onModelDownloaded!();
              }
              statusNotifier.value = ModelDownloadState.ready;
              showSuccessSnackBar('Smart Search is ready!');
            } else {
              debugPrint('ModelDownloadService: Hash mismatch.');
              statusNotifier.value = ModelDownloadState.idle;
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

    statusNotifier.value = ModelDownloadState.idle;
    progressNotifier.value = 0.0;

    try {
      await _channel.invokeMethod('cancelDownload', {'subPath': _subPath});
    } catch (_) {}
  }
}

/// Verifies local ONNX model file integrity against expected SHA-256 signatures.
class ModelVerifier {
  static const String expectedModelSha256 =
      '6c9c6101a956d62dfb5e7190c538226c0c5bb9cb27b651234b6df063ee7dbfe4';

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
