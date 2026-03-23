import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'bert_tokenizer.dart';

// Actually compute sqrt for L2 norm
import 'dart:math';

/// Service for running BERT inference using ONNX Runtime
class OnnxBertService {
  static final OnnxBertService _instance = OnnxBertService._internal();
  factory OnnxBertService() => _instance;
  OnnxBertService._internal();

  OrtSession? _session;
  OrtSessionOptions? _sessionOptions;
  BertTokenizer? _tokenizer;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Future<bool>? _initFuture;

  /// Initialize the ONNX model and tokenizer
  Future<bool> initialize() async {
    if (_isLoaded) return true;
    
    if (_initFuture != null) {
      return await _initFuture!;
    }

    _initFuture = _doInitialize();
    final result = await _initFuture!;
    _initFuture = null;
    return result;
  }

  Future<bool> _doInitialize() async {
    try {
      // Initialize ONNX Runtime environment
      OrtEnv.instance.init();

      // Load model from assets
      const assetFileName = 'assets/models/model.onnx';
      final rawAssetFile = await rootBundle.load(assetFileName);
      final bytes = rawAssetFile.buffer.asUint8List();

      // Create session options and session
      _sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, _sessionOptions!);

      // Load tokenizer
      _tokenizer = BertTokenizer();
      await _tokenizer!.loadTokenizer();

      _isLoaded = true;
      print('ONNX BERT model loaded successfully');
      return true;
    } catch (e) {
      print('Error loading ONNX model: $e');
      return false;
    }
  }

  /// Generate embedding for a text query
  Future<List<double>?> embed(String text) async {
    if (!_isLoaded) {
      final loaded = await initialize();
      if (!loaded) return null;
    }

    try {
      // Tokenize input
      final encoded = _tokenizer!.encode(text);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;
      // token_type_ids: all zeros for single-sentence input
      final tokenTypeIds = List<int>.filled(inputIds.length, 0);

      // Create input tensors
      final inputIdsData = Int64List.fromList(inputIds);
      final attentionMaskData = Int64List.fromList(attentionMask);
      final tokenTypeIdsData = Int64List.fromList(tokenTypeIds);

      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        inputIdsData,
        [1, inputIds.length],
      );
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        attentionMaskData,
        [1, attentionMask.length],
      );
      final tokenTypeIdsTensor = OrtValueTensor.createTensorWithDataList(
        tokenTypeIdsData,
        [1, tokenTypeIds.length],
      );

      // Prepare inputs map
      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
        'token_type_ids': tokenTypeIdsTensor,
      };

      // Run inference
      final runOptions = OrtRunOptions();
      final outputs = await _session?.runAsync(runOptions, inputs);

      // Release input tensors and run options
      inputIdsTensor.release();
      attentionMaskTensor.release();
      tokenTypeIdsTensor.release();
      runOptions.release();

      if (outputs == null || outputs.isEmpty) {
        return null;
      }

      // Get the output embedding
      // The model outputs last_hidden_state - we need to do mean pooling
      final outputValue = outputs[0]?.value;

      List<double>? embedding;

      if (outputValue is List && outputValue.isNotEmpty) {
        final first = outputValue[0];
        if (first is List && first.isNotEmpty && first[0] is List) {
          // 3D: [batch=1, seq_len, hidden_size] - mean pool over sequence
          final seqList = (first as List)
              .map((row) => (row as List).map((v) => (v as num).toDouble()).toList())
              .toList();
          embedding = _meanPooling3D(seqList, attentionMask);
        } else if (first is List) {
          // 2D: [batch=1, hidden_size] - already pooled
          embedding = first.map((e) => (e as num).toDouble()).toList();
        } else if (outputValue[0] is num) {
          // 1D flat list (rare)
          embedding = outputValue.map((e) => (e as num).toDouble()).toList();
        }
      }

      // Release outputs
      for (final output in outputs) {
        output?.release();
      }

      if (embedding != null) {
        // Normalize the embedding
        return _normalize(embedding);
      }

      return null;
    } catch (e) {
      print('Error running BERT inference: $e');
      return null;
    }
  }

  /// Mean pooling over sequence dimension for 3D tensor
  List<double> _meanPooling3D(
    List<List> sequenceOutput,
    List<int> attentionMask,
  ) {
    final seqLen = sequenceOutput.length;
    final hiddenSize = (sequenceOutput[0] as List).length;

    final pooled = List<double>.filled(hiddenSize, 0.0);
    int validTokens = 0;

    for (int i = 0; i < seqLen; i++) {
      if (i < attentionMask.length && attentionMask[i] == 1) {
        final tokenEmb = sequenceOutput[i] as List;
        for (int j = 0; j < hiddenSize; j++) {
          pooled[j] += (tokenEmb[j] as num).toDouble();
        }
        validTokens++;
      }
    }

    if (validTokens > 0) {
      for (int j = 0; j < hiddenSize; j++) {
        pooled[j] /= validTokens;
      }
    }

    return pooled;
  }

  /// L2 normalize the embedding
  List<double> _normalize(List<double> embedding) {
    double sumSq = 0.0;
    for (final v in embedding) {
      sumSq += v * v;
    }
    final norm = sumSq > 0 ? sqrt(sumSq) : 1.0;
    return embedding.map((v) => v / norm).toList();
  }

  /// Dispose resources
  void dispose() {
    _session?.release();
    _sessionOptions?.release();
    OrtEnv.instance.release();
    _session = null;
    _sessionOptions = null;
    _isLoaded = false;
  }
}
