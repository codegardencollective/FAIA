import 'package:equatable/equatable.dart';

/// Data model for chat messages
class ChatMessage extends Equatable {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? intent;
  final double? confidence;
  final int? inferenceTimeMs;
  final bool isSystem;
  
  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.intent,
    this.confidence,
    this.inferenceTimeMs,
    this.isSystem = false,
  });
  
  /// Create a copy with updated fields
  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? intent,
    double? confidence,
    int? inferenceTimeMs,
    bool? isSystem,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      intent: intent ?? this.intent,
      confidence: confidence ?? this.confidence,
      inferenceTimeMs: inferenceTimeMs ?? this.inferenceTimeMs,
      isSystem: isSystem ?? this.isSystem,
    );
  }
  
  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'intent': intent,
      'confidence': confidence,
      'inferenceTimeMs': inferenceTimeMs,
      'isSystem': isSystem,
    };
  }
  
  /// Create from JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      text: json['text'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      intent: json['intent'] as String?,
      confidence: json['confidence'] as double?,
      inferenceTimeMs: json['inferenceTimeMs'] as int?,
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
  
  /// Get formatted timestamp
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  /// Get confidence percentage
  String get confidencePercentage {
    if (confidence == null) return '';
    return '${(confidence! * 100).toStringAsFixed(1)}%';
  }
  
  /// Check if message has AI metadata
  bool get hasAIMetadata => intent != null && confidence != null;
  
  @override
  List<Object?> get props => [
    id,
    text,
    isUser,
    timestamp,
    intent,
    confidence,
    inferenceTimeMs,
    isSystem,
  ];
  
  @override
  String toString() {
    return 'ChatMessage(id: $id, text: "$text", isUser: $isUser, intent: $intent, confidence: $confidence)';
  }
}