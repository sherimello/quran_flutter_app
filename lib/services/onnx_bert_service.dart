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
  bool _isLoading = false;

  bool get isLoaded => _isLoaded;

  /// Initialize the ONNX model and tokenizer
  Future<bool> initialize() async {
    if (_isLoaded) return true;
    if (_isLoading) return false;

    _isLoading = true;

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
      _isLoading = false;
      print('ONNX BERT model loaded successfully');
      return true;
    } catch (e) {
      print('Error loading ONNX model: $e');
      _isLoading = false;
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

      // Create input tensors
      final inputIdsData = Int64List.fromList(inputIds);
      final attentionMaskData = Int64List.fromList(attentionMask);

      final inputIdsTensor = OrtValueTensor.createTensorWithDataList(
        inputIdsData,
        [1, inputIds.length],
      );
      final attentionMaskTensor = OrtValueTensor.createTensorWithDataList(
        attentionMaskData,
        [1, attentionMask.length],
      );

      // Prepare inputs map
      final inputs = {
        'input_ids': inputIdsTensor,
        'attention_mask': attentionMaskTensor,
      };

      // Run inference
      final runOptions = OrtRunOptions();
      final outputs = await _session?.runAsync(runOptions, inputs);

      // Release input tensors and run options
      inputIdsTensor.release();
      attentionMaskTensor.release();
      runOptions.release();

      if (outputs == null || outputs.isEmpty) {
        return null;
      }

      // Get the output embedding
      // The model outputs last_hidden_state - we need to do mean pooling
      final outputValue = outputs[0]?.value;
      
      List<double>? embedding;
      
      if (outputValue is List) {
        // Handle 3D output: [batch, sequence, hidden_size]
        // Need to do mean pooling
        if (outputValue.isNotEmpty && outputValue[0] is List) {
          final sequenceOutput = outputValue[0] as List;
          if (sequenceOutput.isNotEmpty && sequenceOutput[0] is List) {
            // 3D: mean pool over sequence dimension
            embedding = _meanPooling3D(sequenceOutput as List<List>, attentionMask);
          } else {
            // 2D: already pooled
            embedding = (sequenceOutput as List).map((e) => (e as num).toDouble()).toList();
          }
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
  List<double> _meanPooling3D(List<List> sequenceOutput, List<int> attentionMask) {
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
    double norm = 0.0;
    for (final v in embedding) {
      norm += v * v;
    }
    norm = norm > 0 ? 1.0 / (norm * 0.5) : 1.0;
    final sqrtNorm = norm > 0 ? sqrt(norm) : 1.0;
    return embedding.map((v) => v / sqrtNorm).toList();
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
