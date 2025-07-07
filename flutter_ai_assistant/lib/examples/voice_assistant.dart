import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/assistant_provider.dart';
import '../models/chat_message.dart';

class VoiceAssistantExample extends StatelessWidget {
  const VoiceAssistantExample({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Assistant Example',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ChangeNotifierProvider(
        create: (context) => AssistantProvider(),
        child: VoiceAssistantScreen(),
      ),
    );
  }
}

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  _VoiceAssistantScreenState createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin {
  final SpeechToText _speechToText = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1000),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    
    await _speechToText.listen(
      onResult: _onSpeechResult,
      listenFor: Duration(seconds: 30),
      pauseFor: Duration(seconds: 5),
    );
    
    setState(() {
      _isListening = true;
    });
    
    _animationController.repeat(reverse: true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() {
      _isListening = false;
    });
    _animationController.stop();
    _animationController.reset();
    
    if (_lastWords.isNotEmpty) {
      context.read<AssistantProvider>().sendMessage(_lastWords);
      _lastWords = '';
    }
  }

  void _onSpeechResult(result) {
    setState(() {
      _lastWords = result.recognizedWords;
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voice AI Assistant'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AssistantProvider>(
              builder: (context, provider, child) {
                return ListView.builder(
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    final message = provider.messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildVoiceInterface(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final isUser = message.isUser;
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) CircleAvatar(child: Icon(Icons.smart_toy)),
          SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUser ? Colors.purple : Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  if (message.confidence != null) ...[
                    SizedBox(height: 4),
                    Text(
                      'Confidence: ${(message.confidence! * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: isUser ? Colors.white70 : Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(width: 8),
          if (isUser) CircleAvatar(child: Icon(Icons.person)),
        ],
      ),
    );
  }

  Widget _buildVoiceInterface() {
    return Container(
      height: 200,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isListening) ...[
            Text(
              'Listening...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            if (_lastWords.isNotEmpty)
              Text(
                _lastWords,
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            SizedBox(height: 16),
          ],
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: FloatingActionButton.large(
                  onPressed: _isListening ? _stopListening : _startListening,
                  backgroundColor: _isListening ? Colors.red : Colors.purple,
                  child: Icon(
                    _isListening ? Icons.mic_off : Icons.mic,
                    size: 32,
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 16),
          Text(
            _speechEnabled
                ? (_isListening ? 'Tap to stop' : 'Tap to speak')
                : 'Speech not available',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}

void main() {
  runApp(VoiceAssistantExample());
}