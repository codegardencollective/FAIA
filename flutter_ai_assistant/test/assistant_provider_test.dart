import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_ai_assistant/providers/assistant_provider.dart';
import 'package:flutter_ai_assistant/services/tflite_assistant.dart';
import 'package:flutter_ai_assistant/models/chat_message.dart';
import 'package:flutter_ai_assistant/models/assistant_state.dart';
import 'package:flutter_ai_assistant/models/prediction_result.dart';

import 'assistant_provider_test.mocks.dart';

@GenerateMocks([TFLiteAssistant])
void main() {
  group('AssistantProvider', () {
    late AssistantProvider provider;
    late MockTFLiteAssistant mockAssistant;

    setUp(() {
      mockAssistant = MockTFLiteAssistant();
      provider = AssistantProvider(assistant: mockAssistant);
    });

    test('initial state should be correct', () {
      expect(provider.state, equals(AssistantState.idle));
      expect(provider.messages, isEmpty);
      expect(provider.isProcessing, isFalse);
    });

    test('should initialize assistant successfully', () async {
      when(mockAssistant.initialize()).thenAnswer((_) async {});
      
      await provider.initialize();
      
      verify(mockAssistant.initialize()).called(1);
      expect(provider.state, equals(AssistantState.ready));
    });

    test('should handle initialization error', () async {
      when(mockAssistant.initialize()).thenThrow(Exception('Init failed'));
      
      await provider.initialize();
      
      expect(provider.state, equals(AssistantState.error));
    });

    test('should send message and receive response', () async {
      // Setup
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'weather_query',
          confidence: 0.95,
          inferenceTime: 50,
        ),
      );

      // Act
      await provider.sendMessage('What\'s the weather?');

      // Assert
      expect(provider.messages.length, equals(2));
      expect(provider.messages[0].text, equals('What\'s the weather?'));
      expect(provider.messages[0].isUser, isTrue);
      expect(provider.messages[1].isUser, isFalse);
      expect(provider.messages[1].confidence, equals(0.95));
      verify(mockAssistant.classify('What\'s the weather?')).called(1);
    });

    test('should handle classification error', () async {
      // Setup
      when(mockAssistant.classify(any)).thenThrow(Exception('Classification failed'));

      // Act
      await provider.sendMessage('Test message');

      // Assert
      expect(provider.messages.length, equals(2));
      expect(provider.messages[1].text, contains('Sorry'));
      expect(provider.state, equals(AssistantState.error));
    });

    test('should clear messages', () async {
      // Setup - add some messages first
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'test',
          confidence: 0.8,
          inferenceTime: 30,
        ),
      );
      
      await provider.sendMessage('Test');
      expect(provider.messages.length, equals(2));

      // Act
      provider.clearMessages();

      // Assert
      expect(provider.messages, isEmpty);
    });

    test('should not send empty or whitespace messages', () async {
      await provider.sendMessage('');
      await provider.sendMessage('   ');
      await provider.sendMessage('\n\t');

      expect(provider.messages, isEmpty);
      verifyNever(mockAssistant.classify(any));
    });

    test('should trim whitespace from messages', () async {
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'test',
          confidence: 0.8,
          inferenceTime: 30,
        ),
      );

      await provider.sendMessage('  Hello World  ');

      expect(provider.messages[0].text, equals('Hello World'));
      verify(mockAssistant.classify('Hello World')).called(1);
    });

    test('should update processing state correctly', () async {
      bool processingStateChanged = false;
      
      provider.addListener(() {
        if (provider.isProcessing) {
          processingStateChanged = true;
        }
      });

      when(mockAssistant.classify(any)).thenAnswer(
        (_) async {
          await Future.delayed(Duration(milliseconds: 100));
          return PredictionResult(
            label: 'test',
            confidence: 0.8,
            inferenceTime: 30,
          );
        },
      );

      await provider.sendMessage('Test');

      expect(processingStateChanged, isTrue);
      expect(provider.isProcessing, isFalse);
    });

    test('should generate appropriate responses for different intents', () async {
      final testCases = [
        ('weather_query', 'What\'s the weather?', 'weather'),
        ('timer_set', 'Set a timer', 'timer'),
        ('music_play', 'Play music', 'music'),
        ('unknown', 'Random text', 'understand'),
      ];

      for (final testCase in testCases) {
        final (intent, query, expectedKeyword) = testCase;
        
        when(mockAssistant.classify(query)).thenAnswer(
          (_) async => PredictionResult(
            label: intent,
            confidence: 0.9,
            inferenceTime: 50,
          ),
        );
        
        await provider.sendMessage(query);
        
        expect(provider.messages.last.text.toLowerCase(), contains(expectedKeyword));
        provider.clearMessages(); // Clear messages for next test case
      }
    });

    test('should return model info', () async {
      final mockModelInfo = ModelInfo(
        inputShape: [1, 128],
        outputShape: [1, 10],
        inputType: 'int32',
        outputType: 'float32',
        numIntents: 10,
        vocabularySize: 5000,
      );
      when(mockAssistant.getModelInfo()).thenReturn(mockModelInfo);

      final modelInfo = provider.getModelInfo();

      expect(modelInfo, equals(mockModelInfo));
      verify(mockAssistant.getModelInfo()).called(1);
    });

    test('should run benchmark and update performance metrics', () async {
      when(mockAssistant.benchmark(iterations: anyNamed('iterations'))).thenAnswer(
        (_) async => BenchmarkResult(
          iterations: 10,
          medianLatencyMs: 50,
          averageLatencyMs: 60,
          averageConfidence: 0.9,
          minLatencyMs: 40,
          maxLatencyMs: 80,
        ),
      );
      when(mockAssistant.initialize()).thenAnswer((_) async {});
      await provider.initialize(); // Ensure assistant is initialized for benchmark

      await provider.runBenchmark();

      expect(provider.totalRequests, equals(10));
      expect(provider.averageLatency, equals(60));
      expect(provider.averageConfidence, equals(0.9));
      verify(mockAssistant.benchmark(iterations: 10)).called(1);
    });

    test('should handle benchmark error', () async {
      when(mockAssistant.benchmark(iterations: anyNamed('iterations'))).thenThrow(Exception('Benchmark failed'));
      when(mockAssistant.initialize()).thenAnswer((_) async {});
      await provider.initialize();

      expect(() => provider.runBenchmark(), throwsA(isA<Exception>()));
      expect(provider.totalRequests, equals(0));
      expect(provider.averageLatency, equals(0));
      expect(provider.averageConfidence, equals(0));
    });
  });
}

@GenerateMocks([TFLiteAssistant])
void main() {
  group('AssistantProvider', () {
    late AssistantProvider provider;
    late MockTFLiteAssistant mockAssistant;

    setUp(() {
      mockAssistant = MockTFLiteAssistant();
      provider = AssistantProvider(assistant: mockAssistant);
    });

    test('initial state should be correct', () {
      expect(provider.state, equals(AssistantState.idle));
      expect(provider.messages, isEmpty);
      expect(provider.isProcessing, isFalse);
      expect(provider.isListening, isFalse);
      expect(provider.currentInput, isEmpty);
      expect(provider.totalRequests, equals(0));
      expect(provider.averageLatency, equals(0));
      expect(provider.averageConfidence, equals(0));
    });

    test('should initialize assistant successfully', () async {
      when(mockAssistant.initialize()).thenAnswer((_) async {});

      await provider.initialize();

      verify(mockAssistant.initialize()).called(1);
      expect(provider.state, equals(AssistantState.ready));
    });

    test('should handle initialization error', () async {
      when(mockAssistant.initialize()).thenThrow(Exception('Init failed'));

      await provider.initialize();

      expect(provider.state, equals(AssistantState.error));
    });

    test('should send message and receive response', () async {
      // Setup
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'weather_query',
          confidence: 0.95,
          inferenceTime: 50,
        ),
      );

      // Act
      await provider.processText('What\'s the weather?');

      // Assert
      expect(provider.messages.length, equals(2));
      expect(provider.messages[0].text, equals('What\'s the weather?'));
      expect(provider.messages[0].isUser, isTrue);
      expect(provider.messages[1].isUser, isFalse);
      expect(provider.messages[1].confidence, equals(0.95));
      verify(mockAssistant.classify('What\'s the weather?')).called(1);
    });

    test('should handle classification error', () async {
      // Setup
      when(mockAssistant.classify(any)).thenThrow(Exception('Classification failed'));

      // Act
      await provider.processText('Test message');

      // Assert
      expect(provider.messages.length, equals(2));
      expect(provider.messages[1].text, contains('Sorry'));
      expect(provider.state, equals(AssistantState.error));
    });

    test('should clear messages', () async {
      // Setup - add some messages first
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'test',
          confidence: 0.8,
          inferenceTime: 30,
        ),
      );

      await provider.processText('Test');
      expect(provider.messages.length, equals(2));

      // Act
      provider.clearMessages();

      // Assert
      expect(provider.messages, isEmpty);
    });

    test('should not send empty or whitespace messages', () async {
      await provider.processText('');
      await provider.processText('   ');
      await provider.processText('\n\t');

      expect(provider.messages, isEmpty);
      verifyNever(mockAssistant.classify(any));
    });

    test('should trim whitespace from messages', () async {
      when(mockAssistant.classify(any)).thenAnswer(
        (_) async => PredictionResult(
          label: 'test',
          confidence: 0.8,
          inferenceTime: 30,
        ),
      );

      await provider.processText('  Hello World  ');

      expect(provider.messages[0].text, equals('Hello World'));
      verify(mockAssistant.classify('Hello World')).called(1);
    });

    test('should update processing state correctly', () async {
      bool processingStateChanged = false;

      provider.addListener(() {
        if (provider.isProcessing) {
          processingStateChanged = true;
        }
      });

      when(mockAssistant.classify(any)).thenAnswer(
        (_) async {
          await Future.delayed(Duration(milliseconds: 100));
          return PredictionResult(
            label: 'test',
            confidence: 0.8,
            inferenceTime: 30,
          );
        },
      );

      await provider.processText('Test');

      expect(processingStateChanged, isTrue);
      expect(provider.isProcessing, isFalse);
    });

    test('should generate appropriate responses for different intents', () async {
      final testCases = [
        ('weather_query', 'What\'s the weather?', 'weather'),
        ('timer_set', 'Set a timer', 'timer'),
        ('music_play', 'Play music', 'music'),
        ('unknown', 'Random text', 'understand'),
      ];

      for (final testCase in testCases) {
        final (intent, query, expectedKeyword) = testCase;

        when(mockAssistant.classify(query)).thenAnswer(
          (_) async => PredictionResult(
            label: intent,
            confidence: 0.9,
            inferenceTime: 50,
          ),
        );

        await provider.processText(query);

        expect(provider.messages.last.text.toLowerCase(), contains(expectedKeyword));
        provider.clearMessages(); // Clear messages for next test case
      }
    });

    test('should return model info', () async {
      final mockModelInfo = ModelInfo(
        inputShape: [1, 128],
        outputShape: [1, 10],
        inputType: 'int32',
        outputType: 'float32',
        numIntents: 10,
        vocabularySize: 5000,
      );
      when(mockAssistant.getModelInfo()).thenReturn(mockModelInfo);

      final modelInfo = provider.getModelInfo();

      expect(modelInfo, equals(mockModelInfo));
      verify(mockAssistant.getModelInfo()).called(1);
    });

    test('should run benchmark and update performance metrics', () async {
      when(mockAssistant.benchmark(iterations: anyNamed('iterations'))).thenAnswer(
        (_) async => BenchmarkResult(
          iterations: 10,
          medianLatencyMs: 50,
          averageLatencyMs: 60,
          averageConfidence: 0.9,
          minLatencyMs: 40,
          maxLatencyMs: 80,
        ),
      );
      when(mockAssistant.initialize()).thenAnswer((_) async {});
      await provider.initialize(); // Ensure assistant is initialized for benchmark

      await provider.runBenchmark();

      expect(provider.totalRequests, equals(10));
      expect(provider.averageLatency, equals(60));
      expect(provider.averageConfidence, equals(0.9));
      verify(mockAssistant.benchmark(iterations: 10)).called(1);
    });

    test('should handle benchmark error', () async {
      when(mockAssistant.benchmark(iterations: anyNamed('iterations'))).thenThrow(Exception('Benchmark failed'));
      when(mockAssistant.initialize()).thenAnswer((_) async {});
      await provider.initialize();

      expect(() => provider.runBenchmark(), throwsA(isA<Exception>()));
      expect(provider.totalRequests, equals(0));
      expect(provider.averageLatency, equals(0));
      expect(provider.averageConfidence, equals(0));
    });

    test('startListening sets isListening to true and updates currentInput', () async {
      provider.startListening();
      expect(provider.isListening, isTrue);
      expect(provider.currentInput, 'Listening...');
    });

    test('stopListening sets isListening to false and clears currentInput', () async {
      provider.startListening();
      provider.stopListening();
      expect(provider.isListening, isFalse);
      expect(provider.currentInput, isEmpty);
    });

    test('updateListeningText updates currentInput', () {
      provider.updateListeningText('Hello world');
      expect(provider.currentInput, 'Hello world');
    });

    test('canAcceptInput is true when not processing and not listening', () {
      expect(provider.canAcceptInput, isTrue);
      provider.processText('test'); // This will set isProcessing to true temporarily
      expect(provider.canAcceptInput, isFalse);
      provider.startListening();
      expect(provider.canAcceptInput, isFalse);
    });

    test('speak calls assistant.speak', () async {
      when(mockAssistant.speak(any)).thenAnswer((_) async {});
      await provider.speak('Hello');
      verify(mockAssistant.speak('Hello')).called(1);
    });

    test('should handle speak error', () async {
      when(mockAssistant.speak(any)).thenThrow(Exception('Speak failed'));
      await provider.speak('Hello');
      // Expect no crash, error is logged internally
    });
  });
}