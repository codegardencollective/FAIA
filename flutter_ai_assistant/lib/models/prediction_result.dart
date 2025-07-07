/// Represents the result of a TensorFlow Lite prediction
class PredictionResult {
  final String label;
  final double confidence;
  final int inferenceTime;
  final Map<String, dynamic> metadata;

  const PredictionResult({
    required this.label,
    required this.confidence,
    required this.inferenceTime,
    this.metadata = const {},
  });

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      label: json['label'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      inferenceTime: json['inference_time'] as int,
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'confidence': confidence,
      'inference_time': inferenceTime,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'PredictionResult(label: $label, confidence: $confidence, inferenceTime: ${inferenceTime}ms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PredictionResult &&
        other.label == label &&
        other.confidence == confidence &&
        other.inferenceTime == inferenceTime;
  }

  @override
  int get hashCode => Object.hash(label, confidence, inferenceTime);
}