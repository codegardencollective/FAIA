# Flutter AI Assistant 🤖

[![Flutter](https://img.shields.io/badge/Flutter-3.22+-blue.svg)](https://flutter.dev)
[![TensorFlow Lite](https://img.shields.io/badge/TensorFlow%20Lite-2.14+-orange.svg)](https://tensorflow.org/lite)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A cross-platform AI assistant built with Flutter and TensorFlow Lite that runs entirely on-device for privacy-preserving conversational experiences.

## 📋 Overview

This project demonstrates the complete workflow presented in the paper **"Building Cross-Platform AI Assistants with Flutter and TensorFlow"** by Fernando May Fuentes (MobileDev 2024, pp. 44-49).

### Key Features

- 🚀 **Cross-Platform**: Single codebase for iOS, Android, Web, and Desktop
- 🔒 **Privacy-First**: All inference happens on-device
- ⚡ **Fast**: Median response latency < 70ms
- 🔋 **Energy Efficient**: 23% battery reduction vs server-driven approach
- 🎯 **Accurate**: 92.8% intent classification accuracy

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     Flutter App (Dart)                     │
├─────────────────────────────────────────────────────────────┤
│              Provider State Management                      │
├─────────────────────────────────────────────────────────────┤
│                TFLite Plugin (Platform Channel)            │
├─────────────────────────────────────────────────────────────┤
│    Android (Java/Kotlin)    │    iOS (Swift/Obj-C++)      │
├─────────────────────────────────────────────────────────────┤
│              TensorFlow Lite C API                         │
├─────────────────────────────────────────────────────────────┤
│         Hardware Acceleration (NNAPI/Metal)               │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Quick Start

### Prerequisites

- Flutter SDK 3.22+
- Python 3.8+ (for model training)
- Android Studio / Xcode (for platform-specific builds)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/code-garden/flutter_ai_assistant.git
   cd flutter_ai_assistant
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Install Python dependencies**
   ```bash
   cd model_training
   pip install -r requirements.txt
   ```

4. **Train and export the model**
   ```bash
   python train_model.py
   python export_tflite.py
   ```

5. **Run the app**
   ```bash
   flutter run
   ```

## 📱 Supported Platforms

| Platform | Status | Hardware Acceleration |
|----------|--------|-----------------------|
| Android  | ✅     | NNAPI                |
| iOS      | ✅     | Metal/Core ML        |
| Web      | ✅     | WebAssembly          |
| Desktop  | ✅     | CPU                  |

## 🧠 Model Details

- **Architecture**: Transformer-based intent classifier
- **Compression**: Dynamic range quantization (32-bit → 8-bit)
- **Size**: ~2.5MB (compressed)
- **Accuracy**: 92.8% on intent classification task

## 📊 Performance Benchmarks

| Device | Baseline Latency | TFLite Latency | Battery Reduction |
|--------|------------------|----------------|-------------------|
| Pixel 7 | 180ms | 68ms | 25% |
| Galaxy S22 | 195ms | 72ms | 24% |
| iPhone 14 | 170ms | 65ms | 22% |
| Moto G Power | 310ms | 98ms | 20% |

## 🔧 Usage

### Basic Implementation

```dart
import 'package:flutter_ai_assistant/flutter_ai_assistant.dart';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ChangeNotifierProvider(
        create: (context) => AssistantProvider(),
        child: ChatScreen(),
      ),
    );
  }
}
```

### Making Predictions

```dart
final assistant = TFLiteAssistant();
final result = await assistant.classify("What's the weather like?");
print(result); // "weather_query"
```

## 🏃‍♂️ Running the Examples

The repository includes several example implementations:

1. **Basic Chat Interface**
   ```bash
   flutter run lib/examples/basic_chat.dart
   ```

2. **Voice Assistant**
   ```bash
   flutter run lib/examples/voice_assistant.dart
   ```

3. **Performance Benchmark**
   ```bash
   flutter run lib/examples/benchmark.dart
   ```

## 🧪 Testing

Run the test suite:

```bash
flutter test
```

Run platform-specific tests:

```bash
# Android
flutter test integration_test/android_test.dart

# iOS
flutter test integration_test/ios_test.dart
```

## 📖 Documentation

- [API Documentation](docs/api.md)
- [Model Training Guide](docs/training.md)
- [Platform-Specific Setup](docs/platform_setup.md)
- [Performance Optimization](docs/optimization.md)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Code Garden Collective Institute
- MobileDev 2024 reviewers
- Flutter and TensorFlow teams

## 📚 Citation

If you use this work in your research, please cite:

```bibtex
@inproceedings{may2024cross,
  title={Building Cross-Platform AI Assistants with Flutter and TensorFlow},
  author={May Fuentes, Fernando},
  booktitle={Proceedings of MobileDev 2024},
  pages={44--49},
  year={2024}
}
```

## 🔗 Related Work

- [Flutter Documentation](https://docs.flutter.dev)
- [TensorFlow Lite Documentation](https://tensorflow.org/lite)
- [On-Device ML Best Practices](https://developers.google.com/ml-kit)

---

Made with ❤️ by the Code Garden Collective
