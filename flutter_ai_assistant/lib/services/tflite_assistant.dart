import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:tflite_flutter_helper/tflite_flutter_helper.dart';
import 'package:logger/logger.dart';

/// Core TensorFlow Lite service for on-device AI inference
class TFLiteAssistant {
  static const String _modelPath = 'assets/models/intent_classifier.tflite';
  static const String _vocabPath = 'assets/models/vocab.txt';
  static const int _maxSequenceLength = 128;
  
  static const MethodChannel _channel = MethodChannel('ai_assistant');
  
  final Logger _logger = Logger();
  
  Interpreter? _interpreter;
  Map<String, int>? _vocabulary;
  List<String>? _intents;
  bool _isInitialized = false;
  
  /// Singleton instance
  static final TFLiteAssistant _instance = TFLiteAssistant._internal();
  factory TFLiteAssistant() => _instance;
  TFLiteAssistant._internal();
  
  /// Initialize the TensorFlow Lite interpreter and load vocabulary
  Future<void> initialize() async {
    try {
      _logger.i('Initializing TFLite Assistant...');
      
      // Load the TensorFlow Lite model
      _interpreter = await Interpreter.fromAsset(_modelPath);
      
      // Configure delegate for hardware acceleration
      await _configureDelegate();
      
      // Load vocabulary and intents
      await _loadVocabulary();
      await _loadIntents();
      
      _isInitialized = true;
      _logger.i('TFLite Assistant initialized successfully');
      
    } catch (e) {
      _logger.e('Failed to initialize TFLite Assistant: $e');
      rethrow;
    }
  }
  
  /// Configure hardware acceleration delegate
  Future<void> _configureDelegate() async {
    try {
      final deviceInfo = await _getDeviceInfo();
      
      if (deviceInfo['platform'] == 'android') {
        // Use NNAPI delegate for Android
        final delegate = NnApiDelegate();
        _interpreter?.modifyGraphWithDelegate(delegate);
        _logger.i('NNAPI delegate configured for Android');
        
      } else if (deviceInfo['platform'] == 'ios') {
        // Use Metal delegate for iOS
        final delegate = MetalDelegate();
        _interpreter?.modifyGraphWithDelegate(delegate);
        _logger.i('Metal delegate configured for iOS');
      }
    } catch (e) {
      _logger.w('Hardware acceleration not available, falling back to CPU: $e');
    }
  }
  
  /// Get device information for platform-specific optimizations
  Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      return await _channel.invokeMethod('getDeviceInfo');
    } catch (e) {
      _logger.w('Failed to get device info: $e');
      return {'platform': 'unknown'};
    }
  }
  
  /// Load vocabulary from assets
  Future<void> _loadVocabulary() async {
    try {
      final vocabData = await rootBundle.loadString(_vocabPath);
      final vocabList = vocabData.split('\n').where((line) => line.isNotEmpty).toList();
      
      _vocabulary = {};
      for (int i = 0; i < vocabList.length; i++) {
        _vocabulary![vocabList[i]] = i;
      }
      
      _logger.i('Loaded vocabulary with ${_vocabulary!.length} tokens');
    } catch (e) {
      _logger.e('Failed to load vocabulary: $e');
      rethrow;
    }
  }
  
  /// Load intent labels
  Future<void> _loadIntents() async {
    try {
      final intentsData = await rootBundle.loadString('assets/models/intents.txt');
      _intents = intentsData.split('\n').where((line) => line.isNotEmpty).toList();
      
      _logger.i('Loaded ${_intents!.length} intent classes');
    } catch (e) {
      _logger.e('Failed to load intents: $e');
      rethrow;
    }
  }
  
  /// Classify user input and return intent with confidence
  Future<ClassificationResult> classify(String text) async {
    if (!_isInitialized) {
      throw StateError('TFLite Assistant not initialized. Call initialize() first.');
    }
    
    try {
      final startTime = DateTime.now();
      
      // Preprocess input text
      final inputTensor = _preprocessText(text);
      
      // Run inference
      final outputTensor = List.filled(_intents!.length, 0.0).reshape([1, _intents!.length]);
      _interpreter!.run(inputTensor, outputTensor);
      
      // Post-process results
      final result = _postprocessOutput(outputTensor[0]);
      
      final endTime = DateTime.now();
      final inferenceTime = endTime.difference(startTime).inMilliseconds;
      
      _logger.d('Inference completed in ${inferenceTime}ms');
      
      return ClassificationResult(
        intent: result.intent,
        confidence: result.confidence,
        inferenceTimeMs: inferenceTime,
        allScores: result.allScores,
      );
      
    } catch (e) {
      _logger.e('Classification failed: $e');
      rethrow;
    }
  }
  
  /// Preprocess text input for model inference
  List<List<int>> _preprocessText(String text) {
    // Tokenize and convert to IDs
    final tokens = _tokenize(text.toLowerCase());
    final tokenIds = tokens.map((token) => _vocabulary![token] ?? 0).toList();
    
    // Pad or truncate to max sequence length
    if (tokenIds.length > _maxSequenceLength) {
      tokenIds.removeRange(_maxSequenceLength, tokenIds.length);
    } else {
      while (tokenIds.length < _maxSequenceLength) {
        tokenIds.add(0); // Padding token
      }
    }
    
    return [tokenIds];
  }
  
  /// Simple tokenization (can be replaced with more sophisticated tokenizer)
  List<String> _tokenize(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
  }
  
  /// Post-process model output to get intent and confidence
  ({String intent, double confidence, List<double> allScores}) _postprocessOutput(List<double> logits) {
    // Apply softmax to get probabilities
    final probabilities = _softmax(logits);
    
    // Find the class with highest probability
    double maxProb = 0.0;
    int maxIndex = 0;
    
    for (int i = 0; i < probabilities.length; i++) {
      if (probabilities[i] > maxProb) {
        maxProb = probabilities[i];
        maxIndex = i;
      }
    }
    
    return (
      intent: _intents![maxIndex],
      confidence: maxProb,
      allScores: probabilities,
    );
  }
  
  /// Apply softmax activation
  List<double> _softmax(List<double> logits) {
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expLogits = logits.map((x) => math.exp(x - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    
    return expLogits.map((x) => x / sumExp).toList();
  }
  
  /// Get model information
  ModelInfo getModelInfo() {
    if (!_isInitialized) {
      throw StateError('TFLite Assistant not initialized');
    }
    
    final inputTensor = _interpreter!.getInputTensor(0);
    final outputTensor = _interpreter!.getOutputTensor(0);
    
    return ModelInfo(
      inputShape: inputTensor.shape,
      outputShape: outputTensor.shape,
      inputType: inputTensor.type.name,
      outputType: outputTensor.type.name,
      numIntents: _intents!.length,
      vocabularySize: _vocabulary!.length,
    );
  }
  
  /// Benchmark inference performance
  Future<BenchmarkResult> benchmark({int iterations = 100}) async {
    if (!_isInitialized) {
      throw StateError('TFLite Assistant not initialized');
    }
    
    final testPhrases = [
      'What is the weather like today?',
      'Set an alarm for 8 AM',
      'Play some music',
      'What time is it?',
      'Call John Smith',
    ];
    
    final latencies = <int>[];
    final accuracies = <double>[];
    
    for (int i = 0; i < iterations; i++) {
      final phrase = testPhrases[i % testPhrases.length];
      final result = await classify(phrase);
      
      latencies.add(result.inferenceTimeMs);
      accuracies.add(result.confidence);
    }
    
    // Calculate statistics
    latencies.sort();
    final medianLatency = latencies[latencies.length ~/ 2];
    final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    final avgAccuracy = accuracies.reduce((a, b) => a + b) / accuracies.length;
    
    return BenchmarkResult(
      iterations: iterations,
      medianLatencyMs: medianLatency,
      averageLatencyMs: avgLatency.round(),
      averageConfidence: avgAccuracy,
      minLatencyMs: latencies.first,
      maxLatencyMs: latencies.last,
    );
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    _logger.i('TFLite Assistant disposed');
  }
}

/// Classification result data class
class ClassificationResult {
  final String intent;
  final double confidence;
  final int inferenceTimeMs;
  final List<double> allScores;
  
  const ClassificationResult({
    required this.intent,
    required this.confidence,
    required this.inferenceTimeMs,
    required this.allScores,
  });
  
  @override
  String toString() => 'ClassificationResult(intent: $intent, confidence: ${confidence.toStringAsFixed(3)}, time: ${inferenceTimeMs}ms)';
}

/// Model information data class
class ModelInfo {
  final List<int> inputShape;
  final List<int> outputShape;
  final String inputType;
  final String outputType;
  final int numIntents;
  final int vocabularySize;
  
  const ModelInfo({
    required this.inputShape,
    required this.outputShape,
    required this.inputType,
    required this.outputType,
    required this.numIntents,
    required this.vocabularySize,
  });
  
  @override
  String toString() => 'ModelInfo(input: $inputShape, output: $outputShape, intents: $numIntents, vocab: $vocabularySize)';
}

/// Benchmark result data class
class BenchmarkResult {
  final int iterations;
  final int medianLatencyMs;
  final int averageLatencyMs;
  final double averageConfidence;
  final int minLatencyMs;
  final int maxLatencyMs;
  
  const BenchmarkResult({
    required this.iterations,
    required this.medianLatencyMs,
    required this.averageLatencyMs,
    required this.averageConfidence,
    required this.minLatencyMs,
    required this.maxLatencyMs,
  });
  
  @override
  String toString() => 'BenchmarkResult(median: ${medianLatencyMs}ms, avg: ${averageLatencyMs}ms, confidence: ${averageConfidence.toStringAsFixed(3)})';
}

// Import math library for exponential function
import 'dart:math' as math;