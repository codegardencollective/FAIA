/// Enum representing the current state of the AI assistant
enum AssistantState {
  /// Assistant is not initialized
  idle,
  
  /// Assistant is initializing
  initializing,
  
  /// Assistant is ready for interactions
  ready,
  
  /// Assistant is processing a request
  processing,
  
  /// Assistant is listening for voice input
  listening,
  
  /// Assistant is speaking
  speaking,
  
  /// Assistant is running benchmarks
  benchmarking,
  
  /// Assistant encountered an error
  error,
}

/// Extension methods for AssistantState
extension AssistantStateExtension on AssistantState {
  /// Get human-readable description
  String get description {
    switch (this) {
      case AssistantState.idle:
        return 'Not initialized';
      case AssistantState.initializing:
        return 'Initializing...';
      case AssistantState.ready:
        return 'Ready';
      case AssistantState.processing:
        return 'Processing...';
      case AssistantState.listening:
        return 'Listening...';
      case AssistantState.speaking:
        return 'Speaking...';
      case AssistantState.benchmarking:
        return 'Running benchmark...';
      case AssistantState.error:
        return 'Error occurred';
    }
  }
  
  /// Check if assistant is busy
  bool get isBusy {
    switch (this) {
      case AssistantState.initializing:
      case AssistantState.processing:
      case AssistantState.listening:
      case AssistantState.speaking:
      case AssistantState.benchmarking:
        return true;
      default:
        return false;
    }
  }
  
  /// Check if assistant can accept input
  bool get canAcceptInput {
    return this == AssistantState.ready;
  }
  
  /// Check if assistant is in error state
  bool get isError {
    return this == AssistantState.error;
  }
  
  /// Check if assistant is ready
  bool get isReady {
    return this == AssistantState.ready;
  }
}