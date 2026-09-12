import 'dart:io';

import 'package:bert_tokenizer/bert_tokenizer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'text_chunker.dart';
import 'vector_math.dart';

/// Manages C++ ONNX Runtime inference sessions, BERT WordPiece tokenization, and BGE-small Float32 vector generation.
class OnnxEmbeddingEngine {
  static const String _modelFileName = 'bge-small-en-v1.5.onnx';
  static const String _vocabAssetPath = 'assets/models/vocab.txt';

  /// Maximum sequence length fed into BGE-small (supports up to 512 tokens).
  static const int _maxSequenceLength = 384;

  static OrtSession? _session;
  static BertTokenizer? _tokenizer;
  static bool _isInitialized = false;

  /// Locates local model binary file on disk across external storage, documents directory, or system temp.
  static Future<File> getLocalModelFile() async {
    // Check Android external storage directory for downloaded ONNX binary.
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final modelFile = File(join(extDir.path, 'models', _modelFileName));
          if (modelFile.existsSync()) {
            return modelFile;
          }
        }
      } catch (e) {
        debugPrint('OnnxEmbeddingEngine: External storage check error: $e');
      }
    }

    // Fall back to application documents directory or system temp directory.
    try {
      final appDocsDir = await getApplicationDocumentsDirectory();
      return File(join(appDocsDir.path, 'models', _modelFileName));
    } catch (_) {
      final tempDir = Directory.systemTemp;
      return File(join(tempDir.path, 'models', _modelFileName));
    }
  }

  /// Ensures model binary is extracted from bundled app assets to disk if available (for local dev/testing).
  static Future<bool> _extractModelAssetIfAvailable(File targetFile) async {
    try {
      await targetFile.parent.create(recursive: true);

      final byteData = await rootBundle.load('assets/models/$_modelFileName');
      await targetFile.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
        flush: true,
      );

      return targetFile.existsSync();
    } catch (_) {
      return false;
    }
  }

  /// Returns whether the model binary exists on disk or is available via bundled assets.
  static Future<bool> isModelAvailable() async {
    try {
      final modelFile = await getLocalModelFile();
      if (modelFile.existsSync()) {
        return true;
      }
      return await _extractModelAssetIfAvailable(modelFile);
    } catch (_) {
      return false;
    }
  }

  /// Initializes native C++ ONNX Runtime environment and constructs session from local model binary.
  static Future<void> init() async {
    if (_isInitialized) return;
    if (!await isModelAvailable()) return;

    try {
      OrtEnv.instance.init();
      final modelFile = await getLocalModelFile();
      _session = OrtSession.fromFile(modelFile, OrtSessionOptions());

      // Read vocabulary directly from bundled app assets into memory
      final vocabData = await rootBundle.loadString(_vocabAssetPath);
      _tokenizer = BertTokenizer.fromStringContent(vocabData);
      _isInitialized = true;
    } catch (e) {
      if (kDebugMode && !kIsWeb && Platform.isAndroid) {
        debugPrint('OnnxEmbeddingEngine: Initialization failed: $e');
      }
    }
  }

  /// Generates 384-dimensional unit-normalized Float32 vector embeddings for input text chunks.
  static Future<List<Float32List>> generateDocumentEmbeddings(
    String text,
  ) async {
    if (!_isInitialized) await init();
    if (_session == null || _tokenizer == null) return [];

    final chunks = TextChunker.chunkText(text);
    if (chunks.isEmpty) return [];

    List<Float32List> documentVectors = [];

    for (final chunk in chunks) {
      try {
        // Convert text chunk into BERT input tensors (input_ids, attention_mask, token_type_ids).
        final bertInput = _tokenizer!.prepareNerInput(
          chunk,
          _maxSequenceLength,
        );
        final shape = [1, _maxSequenceLength];

        // Allocate native C++ OrtValueTensors for ONNX model input execution.
        final inputOrt = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(bertInput.inputIds),
          shape,
        );
        final maskOrt = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(bertInput.inputMask),
          shape,
        );
        final typeOrt = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList(bertInput.segmentIds),
          shape,
        );

        final inputs = {
          'input_ids': inputOrt,
          'attention_mask': maskOrt,
          'token_type_ids': typeOrt,
        };
        final runOptions = OrtRunOptions();

        // Execute C++ neural network forward pass to retrieve last_hidden_state output tensor.
        final outputs = _session!.run(runOptions, inputs);

        final lastHiddenIndex = _session!.outputNames.indexOf(
          'last_hidden_state',
        );
        final val = outputs[lastHiddenIndex != -1 ? lastHiddenIndex : 0]?.value;

        if (val is List && val.isNotEmpty) {
          final batchZero = val[0] as List;
          if (batchZero.isNotEmpty) {
            // BGE models encode document-level semantic representations in the leading [CLS] token (index 0).
            final clsRaw = batchZero[0] as List;
            final clsVector = clsRaw.map((e) => (e as num).toDouble()).toList();
            documentVectors.add(VectorMath.normalize(clsVector));
          }
        }

        // Release C++ OrtValueTensor memory allocations
        inputOrt.release();
        maskOrt.release();
        typeOrt.release();
        runOptions.release();
        for (var output in outputs) {
          output?.release();
        }
      } catch (e) {
        debugPrint('OnnxEmbeddingEngine: Chunk embedding error: $e');
      }
    }
    return documentVectors;
  }
}
