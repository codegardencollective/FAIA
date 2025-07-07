import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:logger/logger.dart';
import '../services/tflite_assistant.dart';
import '../models/chat_message.dart';
import '../models/assistant_state.dart';

/// Provider for managing AI assistant state and interactions
class AssistantProvider extends ChangeNotifier {
  final Logger _logger = Logger();
  final TFLiteAssistant _tfliteAssistant = TFLiteAssistant();
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  
  // State variables
  AssistantState _state = AssistantState.idle;
  final List<ChatMessage> _messages = [];
  String _currentInput = '';
  bool _isListening = false;
  bool _isSpeaking = false;
  bool _isProcessing = false;
  String _lastError = '';
  
  // Performance tracking
  int _totalRequests = 0;
  int _totalInferenceTime = 0;
  double _averageConfidence = 0.0;
  
  // Getters
  AssistantState get state => _state;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  String get currentInput => _currentInput;
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  bool get isProcessing => _isProcessing;
  String get lastError => _lastError;
  bool get isInitialized => _state != AssistantState.idle;
  
  // Performance metrics
  int get totalRequests => _totalRequests;
  double get averageLatency => _totalRequests > 0 ? _totalInferenceTime / _totalRequests : 0.0;
  double get averageConfidence => _averageConfidence;
  
  /// Initialize the assistant
  Future<void> initialize() async {
    try {
      _setState(AssistantState.initializing);
      _logger.i('Initializing AI Assistant...');
      
      // Initialize TensorFlow Lite
      await _tfliteAssistant.initialize();
      
      // Initialize speech recognition
      await _initializeSpeechRecognition();
      
      // Initialize text-to-speech
      await _initializeTextToSpeech();
      
      // Add welcome message
      _addSystemMessage('AI Assistant initialized! How can I help you today?');
      
      _setState(AssistantState.ready);
      _logger.i('AI Assistant initialized successfully');
      
    } catch (e) {
      _logger.e('Failed to initialize AI Assistant: $e');
      _setError('Failed to initialize: ${e.toString()}');
      _setState(AssistantState.error);
    }
  }
  
  /// Initialize speech recognition
  Future<void> _initializeSpeechRecognition() async {
    try {
      final available = await _speechToText.initialize(
        onStatus: (status) {
          _logger.d('Speech recognition status: $status');
          if (status == 'notListening') {
            _setListening(false);
          }
        },
        onError: (error) {
          _logger.e('Speech recognition error: $error');
          _setError('Speech recognition error: ${error.errorMsg}');
          _setListening(false);
        },
      );
      
      if (!available) {
        throw Exception('Speech recognition not available');
      }
      
      _logger.i('Speech recognition initialized');
    } catch (e) {
      _logger.w('Speech recognition initialization failed: $e');
      // Continue without speech recognition
    }
  }
  
  /// Initialize text-to-speech
  Future<void> _initializeTextToSpeech() async {
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5);
      
      _flutterTts.setStartHandler(() {
        _setSpeaking(true);
      });
      
      _flutterTts.setCompletionHandler(() {
        _setSpeaking(false);
      });
      
      _flutterTts.setErrorHandler((msg) {
        _logger.e('TTS error: $msg');
        _setSpeaking(false);
      });
      
      _logger.i('Text-to-speech initialized');
    } catch (e) {
      _logger.w('Text-to-speech initialization failed: $e');
      // Continue without TTS
    }
  }
  
  /// Process text input
  Future<void> processText(String text) async {
    if (_state != AssistantState.ready || text.trim().isEmpty) {
      return;
    }
    
    try {
      _setProcessing(true);
      _setCurrentInput(text);
      
      // Add user message
      _addUserMessage(text);
      
      // Classify intent
      final result = await _tfliteAssistant.classify(text);
      
      // Update performance metrics
      _updatePerformanceMetrics(result);
      
      // Generate response based on intent
      final response = await _generateResponse(result);
      
      // Add assistant response
      _addAssistantMessage(response, result);
      
      _logger.i('Processed input: "$text" -> Intent: ${result.intent} (${result.confidence.toStringAsFixed(3)})');
      
    } catch (e) {
      _logger.e('Failed to process text: $e');
      _setError('Failed to process input: ${e.toString()}');
      _addSystemMessage('Sorry, I encountered an error processing your request.');
    } finally {
      _setProcessing(false);
      _setCurrentInput('');
    }
  }
  
  /// Generate response based on classification result
  Future<String> _generateResponse(ClassificationResult result) async {
    final intent = result.intent;
    final confidence = result.confidence;
    
    // Low confidence threshold
    if (confidence < 0.5) {
      return "I'm not sure I understand. Could you please rephrase that?";
    }
    
    // Generate response based on intent
    switch (intent) {
      case 'greeting':
        return _getRandomResponse([
          'Hello! How can I help you today?',
          'Hi there! What can I do for you?',
          'Hey! How are you doing?',
        ]);
      
      case 'weather':
        return 'I can see you\'re asking about the weather. I\'m an on-device assistant, so I can\'t access real-time weather data, but I can help you with other tasks!';
      
      case 'time':
        final now = DateTime.now();
        return 'The current time is ${now.hour}:${now.minute.toString().padLeft(2, '0')}.';
      
      case 'music':
        return 'I understand you want to play music! I\'m focused on text processing, but I can help you with other tasks.';
      
      case 'alarm':
        return 'I can see you want to set an alarm. While I can\'t actually set alarms, I can help you with text-based tasks!';
      
      case 'call':
        return 'I understand you want to make a call. I\'m a text-based assistant, so I can\'t make calls, but I can help you with other tasks!';
      
      case 'help':
        return 'I\'m an AI assistant that can help you with various tasks. I can understand your intent and provide helpful responses. Try asking me about the weather, time, or just say hello!';
      
      case 'goodbye':
        return _getRandomResponse([
          'Goodbye! Have a great day!',
          'See you later!',
          'Take care!',
        ]);
      
      default:
        return 'I understand you\'re asking about ${intent.replaceAll('_', ' ')}. I\'m still learning, but I\'m here to help!';
    }
  }
  
  /// Get random response from a list
  String _getRandomResponse(List<String> responses) {
    return responses[DateTime.now().millisecondsSinceEpoch % responses.length];
  }
  
  /// Start voice input
  Future<void> startListening() async {
    if (!_speechToText.isAvailable || _isListening) {
      return;
    }
    
    try {
      _setListening(true);
      
      await _speechToText.listen(
        onResult: (result) {
          _setCurrentInput(result.recognizedWords);
          
          if (result.finalResult) {
            _setListening(false);
            processText(result.recognizedWords);
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
      );
      
    } catch (e) {
      _logger.e('Failed to start listening: $e');
      _setError('Failed to start voice input: ${e.toString()}');
      _setListening(false);
    }
  }
  
  /// Stop voice input
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      await _speechToText.stop();
      _setListening(false);
    } catch (e) {
      _logger.e('Failed to stop listening: $e');
    }
  }
  
  /// Speak text aloud
  Future<void> speak(String text) async {
    if (_isSpeaking || text.trim().isEmpty) {
      return;
    }
    
    try {
      await _flutterTts.speak(text);
    } catch (e) {
      _logger.e('Failed to speak: $e');
    }
  }
  
  /// Stop speaking
  Future<void> stopSpeaking() async {
    if (!_isSpeaking) return;
    
    try {
      await _flutterTts.stop();
      _setSpeaking(false);
    } catch (e) {
      _logger.e('Failed to stop speaking: $e');
    }
  }
  
  /// Clear chat history
  void clearMessages() {
    _messages.clear();
    _addSystemMessage('Chat cleared. How can I help you?');
    notifyListeners();
  }
  
  /// Run performance benchmark
  Future<BenchmarkResult> runBenchmark({int iterations = 100}) async {
    if (_state != AssistantState.ready) {
      throw StateError('Assistant not ready for benchmarking');
    }
    
    _setState(AssistantState.benchmarking);
    
    try {
      final result = await _tfliteAssistant.benchmark(iterations: iterations);
      _addSystemMessage('Benchmark completed: ${result.toString()}');
      return result;
    } catch (e) {
      _logger.e('Benchmark failed: $e');
      _setError('Benchmark failed: ${e.toString()}');
      rethrow;
    } finally {
      _setState(AssistantState.ready);
    }
  }
  
  /// Update performance metrics
  void _updatePerformanceMetrics(ClassificationResult result) {
    _totalRequests++;
    _totalInferenceTime += result.inferenceTimeMs;
    _averageConfidence = (_averageConfidence * (_totalRequests - 1) + result.confidence) / _totalRequests;
  }
  
  /// Add user message
  void _addUserMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
    );
    _messages.add(message);
    notifyListeners();
  }
  
  /// Add assistant message
  void _addAssistantMessage(String text, ClassificationResult result) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      intent: result.intent,
      confidence: result.confidence,
      inferenceTimeMs: result.inferenceTimeMs,
    );
    _messages.add(message);
    notifyListeners();
  }
  
  /// Add system message
  void _addSystemMessage(String text) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      isSystem: true,
    );
    _messages.add(message);
    notifyListeners();
  }
  
  /// Set current state
  void _setState(AssistantState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }
  
  /// Set current input
  void _setCurrentInput(String input) {
    if (_currentInput != input) {
      _currentInput = input;
      notifyListeners();
    }
  }
  
  /// Set listening state
  void _setListening(bool listening) {
    if (_isListening != listening) {
      _isListening = listening;
      notifyListeners();
    }
  }
  
  /// Set speaking state
  void _setSpeaking(bool speaking) {
    if (_isSpeaking != speaking) {
      _isSpeaking = speaking;
      notifyListeners();
    }
  }
  
  /// Set processing state
  void _setProcessing(bool processing) {
    if (_isProcessing != processing) {
      _isProcessing = processing;
      notifyListeners();
    }
  }
  
  /// Set error message
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }
  
  /// Clear error
  void clearError() {
    _lastError = '';
    notifyListeners();
  }
  
  /// Get model information
  ModelInfo? getModelInfo() {
    try {
      return _tfliteAssistant.getModelInfo();
    } catch (e) {
      _logger.e('Failed to get model info: $e');
      return null;
    }
  }
  
  @override
  void dispose() {
    _speechToText.stop();
    _flutterTts.stop();
    _tfliteAssistant.dispose();
    super.dispose();
  }
}