import 'dart:convert';
import 'package:flutter/services.dart';

/// WordPiece tokenizer for BERT models
/// Parses the HuggingFace tokenizer.json format
class BertTokenizer {
  Map<String, int>? _vocab;
  bool _isLoaded = false;
  
  // Special token IDs (will be loaded from config)
  int _clsTokenId = 101;
  int _sepTokenId = 102;
  int _padTokenId = 0;
  int _unkTokenId = 100;
  
  static const int maxLength = 128;

  /// Load tokenizer from HuggingFace tokenizer.json format
  Future<void> loadTokenizer({String path = 'assets/models/tokenizer.json'}) async {
    if (_isLoaded) return;

    try {
      final jsonString = await rootBundle.loadString(path);
      final tokenizer = json.decode(jsonString);
      
      // Extract vocabulary from the tokenizer model
      final model = tokenizer['model'];
      if (model != null && model['vocab'] != null) {
        _vocab = Map<String, int>.from(model['vocab']);
      }
      
      // Load special tokens
      final addedTokens = tokenizer['added_tokens'] as List?;
      if (addedTokens != null) {
        for (final token in addedTokens) {
          final content = token['content'] as String?;
          final id = token['id'] as int?;
          if (content != null && id != null) {
            _vocab?[content] = id;
            if (content == '[CLS]') _clsTokenId = id;
            if (content == '[SEP]') _sepTokenId = id;
            if (content == '[PAD]') _padTokenId = id;
            if (content == '[UNK]') _unkTokenId = id;
          }
        }
      }
      
      _isLoaded = true;
      print('Loaded tokenizer with ${_vocab?.length ?? 0} tokens');
    } catch (e) {
      print('Error loading tokenizer: $e');
      // Fallback: try loading vocab.txt
      await _loadVocabTxt();
    }
  }

  /// Fallback: Load vocabulary from vocab.txt file
  Future<void> _loadVocabTxt() async {
    try {
      final vocabString = await rootBundle.loadString('assets/models/vocab.txt');
      final lines = vocabString.split('\n');
      
      _vocab = {};
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab![token] = i;
        }
      }
      
      _isLoaded = true;
      print('Loaded vocab.txt with ${_vocab!.length} tokens');
    } catch (e) {
      print('Error loading vocab.txt: $e');
      throw Exception('Failed to load tokenizer');
    }
  }

  /// Tokenize text and return input_ids and attention_mask
  Map<String, List<int>> encode(String text) {
    if (!_isLoaded || _vocab == null) {
      throw Exception('Tokenizer not loaded. Call loadTokenizer() first.');
    }

    // Preprocessing
    text = text.toLowerCase().trim();
    
    // Tokenize into subwords
    final tokens = _tokenize(text);
    
    // Convert tokens to IDs: [CLS] + tokens + [SEP]
    List<int> inputIds = [_clsTokenId];
    for (final token in tokens) {
      inputIds.add(_vocab![token] ?? _unkTokenId);
    }
    inputIds.add(_sepTokenId);
    
    // Truncate if needed
    if (inputIds.length > maxLength) {
      inputIds = inputIds.sublist(0, maxLength - 1);
      inputIds.add(_sepTokenId);
    }
    
    // Create attention mask
    List<int> attentionMask = List.filled(inputIds.length, 1);
    
    // Pad to maxLength
    final padLength = maxLength - inputIds.length;
    if (padLength > 0) {
      inputIds.addAll(List.filled(padLength, _padTokenId));
      attentionMask.addAll(List.filled(padLength, 0));
    }
    
    return {
      'input_ids': inputIds,
      'attention_mask': attentionMask,
    };
  }

  /// WordPiece tokenization
  List<String> _tokenize(String text) {
    // Split on whitespace and punctuation
    final words = text.split(RegExp(r'[\s.,;:!?()"[\]{}<>]+'));
    final tokens = <String>[];
    
    for (final word in words) {
      if (word.isEmpty) continue;
      
      // Check if whole word exists
      if (_vocab!.containsKey(word)) {
        tokens.add(word);
        continue;
      }
      
      // WordPiece: break into subwords
      tokens.addAll(_wordPieceTokenize(word));
    }
    
    return tokens;
  }

  /// Break a word into WordPiece subwords
  List<String> _wordPieceTokenize(String word) {
    final subwords = <String>[];
    int start = 0;
    
    while (start < word.length) {
      int end = word.length;
      String? foundSubword;
      
      // Find longest matching subword
      while (start < end) {
        String substr = word.substring(start, end);
        if (start > 0) {
          substr = '##$substr';
        }
        
        if (_vocab!.containsKey(substr)) {
          foundSubword = substr;
          break;
        }
        end--;
      }
      
      if (foundSubword != null) {
        subwords.add(foundSubword);
        start = end;
      } else {
        // Unknown character, add [UNK] and move forward
        if (start == 0) {
          subwords.add('[UNK]');
        }
        start++;
      }
    }
    
    return subwords.isEmpty ? ['[UNK]'] : subwords;
  }

  bool get isLoaded => _isLoaded;
}
