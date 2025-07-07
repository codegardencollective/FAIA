import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceInput extends StatefulWidget {
  final Function(String) onResult;
  final VoidCallback? onListening;
  final VoidCallback? onStopped;

  const VoiceInput({
    Key? key,
    required this.onResult,
    this.onListening,
    this.onStopped,
  }) : super(key: key);

  @override
  State<VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInput>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _lastWords = '';
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _initSpeech();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: _onSpeechStatus,
      onError: _onSpeechError,
    );
    setState(() {});
  }

  void _onSpeechStatus(String status) {
    setState(() {
      _isListening = status == 'listening';
    });
    
    if (_isListening) {
      _animationController.repeat(reverse: true);
      widget.onListening?.call();
    } else {
      _animationController.stop();
      _animationController.reset();
      widget.onStopped?.call();
    }
  }

  void _onSpeechError(dynamic error) {
    setState(() {
      _isListening = false;
    });
    _animationController.stop();
    _animationController.reset();
    widget.onStopped?.call();
  }

  void _startListening() async {
    if (!_isAvailable) return;
    
    await _speech.listen(
      onResult: (result) {
        setState(() {
          _lastWords = result.recognizedWords;
        });
        if (result.finalResult) {
          widget.onResult(_lastWords);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      partialResults: true,
      localeId: 'en_US',
      onSoundLevelChange: null,
      cancelOnError: true,
    );
  }

  void _stopListening() async {
    await _speech.stop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isListening && _lastWords.isNotEmpty) ...[
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.primary.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.mic,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _lastWords,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            return Transform.scale(
              scale: _isListening ? _animation.value : 1.0,
              child: FloatingActionButton(
                onPressed: _isAvailable
                    ? (_isListening ? _stopListening : _startListening)
                    : null,
                backgroundColor: _isListening
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                foregroundColor: _isListening
                    ? theme.colorScheme.onError
                    : theme.colorScheme.onPrimary,
                child: Icon(
                  _isListening ? Icons.mic_off : Icons.mic,
                  size: 28,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          _isListening ? 'Listening...' : 'Tap to speak',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}